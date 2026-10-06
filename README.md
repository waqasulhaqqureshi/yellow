# ♞ Chess Arena

Play chess against smart offline bots: adaptive difficulty, ELO rating,
blunder tracking and a bot that actually talks back.

## Features (v1 — offline)

* **Find Opponent** — radar matchmaking reveals a bot with random name,
  country flag, avatar, rating, tier and personality.
* **Strong, human-like engine** — `genetom_chess_engine` rules + a custom
  time-boxed search (negamax, alpha-beta, MVV-LVA ordering, quiescence),
  opening book, deliberate-error model and mercy logic. Never hangs.
* **ELO from 1000** — dynamic K-factor, win/draw/loss preview before the
  game, +5/+6-style lively deltas, streaks, history (Hive, offline).
* **Blunder tracking** — every human move is graded (Brilliant → Blunder)
  and the bot reacts to big moments.
* **Contextual chat** — on-device ML Kit Smart Reply reads your messages,
  with intent detection + a personality-flavoured event matrix as fallback.
  Works fully offline (model downloads once).
* **Full game flow** — promotion picker, draw offers the bot judges,
  resign, rematch-the-same-bot, stalemate correction.

## Run

```bash
flutter pub get
flutter run            # Android device / emulator
```

Requirements: Flutter 3.27+ (Dart 3.6+ SDK constraint is ^3.12),
Android minSdk 21 (set for ML Kit), Google Play Services on the device
for Smart Reply (falls back gracefully without it).

## Project layout

```
lib/
  main.dart
  core/            theme, hive setup, piece glyphs, flag/avatar widgets
  features/
    bot/           bot identity (names, flags, generator, tiers)
    engine/        ArenaBrain, ArenaSearch, book, eval, blunder tracker
    matchmaking/   OpponentSource seam + searching controller
    chat/          ML Kit wrapper, matrix, chat brain
    game/          controller, board UI, screens
    profile/       Hive profile + history repository
    rating/        ELO service
docs/
  ENGINE_NOTES.md         how the bot thinks + tuning guide
  SUPABASE_ONLINE_PLAN.md v2 online multiplayer plug-in plan (SQL incl.)
```

## Roadmap

* v1.1 — search in a background isolate, human-as-Black, hint/undo.
* v2 — Supabase online matchmaking with bot fallback (plan in docs).
