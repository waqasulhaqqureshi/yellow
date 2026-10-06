# Human-like bot behaviors

The arena bot is not a bare engine. A behavior layer (`lib/features/engine/human_behavior.dart`)
and a social layer (`lib/features/chat/*`) layer human imperfection and personality on top of
the time-boxed search. Every item below is implemented and wired into live play; the
`HumanBehavior` enum lets the game-over summary and debug tooling enumerate exactly which
behaviors fired in a given game.

## Board behaviors (`HumanBehaviorEngine`)

| # | Behavior | What it does |
|---|----------|--------------|
| 1 | `openingConfidence` | First plies are played fast, like a human rattling off theory. |
| 2 | `recaptureInstinct` | An obvious recapture is nearly instant. |
| 3 | `exploitPause` | After your blunder the bot "double-checks" before taking the piece. |
| 4 | `surprisePause` | A brilliant move from you causes a longer think. |
| 5 | `timeTroublePanic` | Under ~30s the bot rushes and makes more errors. |
| 6 | `fatigue` | In long games (>60 plies) the error rate creeps up. |
| 7 | `tiltAfterBlunder` | After its own blunder the bot is shaky / tilted next move. |
| 8 | `mercy` | When crushing you, the bot eases off so you can fight back. |
| 9 | `resignation` | Personality-aware resignation when genuinely lost (see controller). |
|10 | `drawOffer` | Offers draws when dead-equal and tired, or slightly worse. |
|11 | `endgameInaccuracy` | Weaker personalities botch endgame technique (depth penalty). |
|12 | `afkPause` | Rare long pause — the human stepped away from the screen. |
|13 | `clockManagement` | Plays quicker when comfortably winning on the clock. |
|14 | `checkReaction` | Answering a check is instinctive and fast. |
|15 | `hesitation` | Two near-equal candidates cause real indecision (longer think). |
|16 | `noShuffle` *(search)* | Deliberate-blunder pool only picks plausible alternatives, never shuffles. |

## Social behaviors (chat persona, `lib/features/chat/persona/*`)

| # | Behavior | What it does |
|---|----------|--------------|
|17 | Persona opener | Friendly bots greet; salty bots open with bravado; quiet bots say little. |
|18 | Asks your origin | Curious bots ask "where are you from?" and follow up on your city. |
|19 | Answers about itself | Bot tells you its country + city consistently (seeded persona). |
|20 | Typos / slang | Probabilistic fat-finger typos, "u/ur/gonna", dropped apostrophes. |
|21 | Leaves you on read | Low-`responseRate` (silent) bots sometimes don't reply at all. |
|22 | Emoji / mood | Cheerful bots sprinkle emoji; formal bots never typo. |

These stack on the existing event-matrix reactions (blunders, checks, captures) and the
heuristic reply engine, so the bot both plays and talks like a person.
