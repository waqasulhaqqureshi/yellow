# Chess Arena — Engine Notes

How the bot thinks, why it is strong, and which quirks of the underlying
package are worked around. Read this before tuning difficulty.

## Architecture

```
Human move ──▶ genetom_chess_engine (rules, board, game-over)
                        │
                        ▼
Bot reply  ◀── ArenaBrain (lib/features/engine/arena_brain.dart)
                        │
        ┌───────────────┼────────────────┐
        ▼               ▼                ▼
  OpeningBook    ArenaSearch      Human-error model
  (17 lines,     (negamax +       (blunder rate,
   ≤10 ply)       alpha-beta +     slack, random,
                   MVV-LVA +       mercy)
                   quiescence,
                   time-boxed)
```

**Legality always comes from `genetom_chess_engine`.** `ArenaSearch` only
returns moves produced by the engine's own move generator, so it can never
play an illegal move — the worst case of any evaluation subtlety is a
slightly weaker (but legal) move.

## Why a custom search on top of the package?

The package's built-in `generateBestMove()` is plain minimax + alpha-beta
with **no move ordering, no quiescence, no time control**:

| Built-in difficulty | Depth | Problem on real phones |
|---|---|---|
| tooEasy / easy | 2–3 | fine, but weak |
| medium | 4 | OK on flagships, slow on low-end |
| hard | 5 | can stall 10–60s mid-game |
| asian | 6 | effectively hangs (minutes) |

`ArenaSearch` fixes all three gaps:

* **MVV-LVA move ordering** — captures-first ordering makes alpha-beta prune
  3–10x more nodes at the same depth.
* **Iterative deepening + hard time box + node cap** — whatever completes in
  the budget is used; slow devices degrade gracefully instead of hanging.
* **Captures-only quiescence (2 ply)** — calms the horizon effect
  (no more "hang a queen, search stops, looks fine").
* **Mate-distance scoring** — prefers faster mates, slower deaths.
* **Auto-queen promotions inside the search** (the built-in search ignores
  promotion entirely).

## Difficulty tiers (lib/features/engine/difficulty_mapper.dart)

| Tier | Rating | Search | Book | Blunder rate / slack | Chaos |
|---|---|---|---|---|---|
| Rookie | <950 | 350ms / d2 | 2 ply | 22% / 500cp | 10% random |
| Club | 950–1150 | 650ms / d3 | 4 ply | 12% / 350cp | 4% random |
| Expert | 1150–1400 | 1200ms / d4 | 6 ply | 6% / 250cp | — |
| Master | 1400–1700 | 2000ms / d5 | 8 ply | 2.5% / 150cp | — |
| Grandmaster | 1700+ | 3000ms / d6 | 10 ply | 0% | — |

Blundering = picking a sane sub-optimal move from the scored root list
(within `slack` of best), *not* a random move — errors look human.

**Mercy:** if the human has 2+ blunders and is worse than −250cp, the bot's
blunder rate rises (+8pp, max 30%) to keep games fun.

**Rubber-banding (matchmaking):** 3+ win streak pulls +120 stronger bots,
3+ loss streak pulls −120 kinder bots.

## Known `genetom_chess_engine` v0.0.4 quirks (handled)

1. **Black pawn promotion never fires.** `_canPromotePawn` checks
   `board[...] == pawnPower` (white only). Workaround: `ArenaBrain`
   auto-queens stranded black pawns on rank 8 after every bot move.
2. **Stalemate is reported as a win.** "Opponent has no legal moves" always
   maps to a win for the mover. Workaround: `GameController` re-checks with
   `ChessEval.isInCheck` on the live board and records stalemates as draws.
3. **No en-passant.** The package has no EP generation, so neither does our
   search — consistent on both sides. Documented limitation.
4. **Board callbacks pass the internal mutable board.** `ArenaBrain` copies
   on every callback; treat all board lists as snapshots.
5. **Game-over fires before the board callback.** `GameController` refreshes
   from the live engine board inside the game-over handler.

## Tuning guide

* Bot too weak/strong overall → adjust `searchTimeMs`/`maxDepth` per tier.
* Bot feels robotic → raise `blunderRate`, widen `blunderSlackCp`.
* Too much opening repetition → add lines to `OpeningBook.lines`.
* Hangs on a weak device → lower `maxDepth`/`searchTimeMs` for Master/GM;
  the greedy fallback guarantees a move regardless.

## v1.1 ideas (structured for, not yet built)

* Run `ArenaSearch` in a background `Isolate` (inputs/outputs are already
  plain data) to keep the thinking animation at 60fps.
* Check evasions in quiescence; killer-move ordering; transposition table.
* Human-as-Black mode (board mirror mapper + flipped search root).
* Hint/undo via engine rebuild from the UCI history.
