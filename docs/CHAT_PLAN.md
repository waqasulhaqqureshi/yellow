# Chat & Group Chat — Behavior Plan

This document is the design contract for the chat pillar: the 1-on-1 in-game
chat and the new group chat. Everything runs on-device (0 MB of new
dependencies); "intelligence" comes from layered intent/NLU matching over a
very large persona corpus plus persona voice transforms.

## 1. Goals

1. Conversations must feel like a person: varied pacing, typos, persona
   voice, memory of your name/city, follow-up questions.
2. Group chat must feel like a room of people talking *to each other*, not
   a queue of bots replying to you.
3. Zero heavy dependencies: no LLM, no tflite, no new pub packages.
4. Corpus is the growth surface: 15,000+ lines generated into
   `lib/features/chat/persona/group_corpus.dart` by `tool/gen_chat_corpus.py`.

## 2. Architecture

```
user text
   │
   ▼
IntentRouter (regex/keyword intents, ordered, first match wins)
   │  intents: greeting, name-tell, name-ask, origin-tell, origin-ask,
   │  age-ask, how-are-you, praise, taunt, thanks, bye, draw-talk,
   │  move-talk, question-general, opinion, food, weather, sport,
   │  study/work, music, tech, joke, agreement, disagreement, laugh
   ▼
Pool selection (topic × ChatStyle)  →  template fill ({name},{bot},{city}…)
   ▼
Voice layer: TypoEngine (style-based typo rate), punctuation, casing,
emoji probability, length clipping (silent style), "!!" (cheerful)
   ▼
Delivery layer: typing delay proportional to message length, occasional
double-message split, read-then-reply pauses
```

## 3. Persona voices (ChatStyle)

| Style    | Casing | Typos | Emoji | Length | Signature |
|----------|--------|-------|-------|--------|-----------|
| salty    | lower  | med   | low   | short  | dry taunts, no caps |
| cheerful | mixed  | low   | high  | med    | `!!`, exclamations |
| formal   | full   | none  | none  | med    | complete sentences |
| silent   | lower  | low   | none  | 1–3 wd | "ok", "gg" |
| rash     | lower  | high  | med   | short  | impulsive, "move move" |
| friendly | mixed  | med   | med   | med    | warm default |

## 4. Group chat model

- **Entry:** home → Group Chat pill. First open shows **Join group /
  Create group** (create is a "coming soon" stub). Join → explore list of
  12 themed groups with member counts, topic, live preview line, Join button.
- **Room:** message stream where 5–9 bot members converse on a schedule
  (6–22 s gaps, bursty: 20% chance a reply-chain of 2–3 quick messages).
- **Ambience vs reaction:** 70% of room traffic is member-to-member
  (two bots riffing on a topic thread); 30% is broadcast banter. When the
  user posts, 1–2 members react within 2–7 s using the IntentRouter; the
  rest keep their ambient thread so the room never feels user-centric.
- **Topic threads:** each group has a dominant topic (openings, memes,
  cricket+chai, endgames, rating climb…). Ambient lines are drawn from that
  topic pool and chained: statement → reaction → follow-up question → answer.
- **Memory:** joined-group ids persisted in Hive box `arena_groups`;
  backlog of last ~40 messages per joined group kept so re-opening a room
  shows history.
- **Identity:** members are BotProfile-style personas (name, flag, style)
  reusing avatar/flag widgets; the user appears with their profile name.

## 5. Anti-robot rules

- No verbatim repeat of a line already shown this session (per-room LRU).
- Two bots never use the same opening word back-to-back.
- Silent members post at most once per ~6 ambient messages.
- Typo rate never applied to formal style; cheerful never sends one-word.
- Human-like latency: longer text ⇒ longer "typing" delay (≈ 35 ms/char,
  capped 4 s) plus 0.5–2 s read pause.

## 6. 1-on-1 in-game chat (existing, extended)

Same router; extra intents wired to game state (draw talk, move talk,
resignation apologies). Bot initiates based on game events (your blunder ⇒
taunt or sympathy by style; its blunder ⇒ excuse by style).

## 7. Corpus generation

`tool/gen_chat_corpus.py` holds hand-written seed fragments per topic and
slot lists (openers/reactions/tails/emoji). It expands them into
15,000+ unique Dart string literals across topic pools, deterministic seed
so regenerations are stable. Quality bar: every emitted line must read as
something a human would type in a casual group chat.
