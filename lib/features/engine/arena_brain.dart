import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:genetom_chess_engine/genetom_chess_engine.dart';

import '../bot/domain/bot_personality.dart';
import '../../core/utils/piece_glyphs.dart';
import 'arena_search.dart';
import 'chess_eval.dart';
import 'difficulty_mapper.dart';
import 'human_behavior.dart';
import 'human_pace.dart';
import 'move_quality.dart';
import 'opening_book.dart';

class HumanMoveOutcome {
  final MoveAssessment assessment;
  final bool isBookMove;

  const HumanMoveOutcome({required this.assessment, required this.isBookMove});
}

class BotMoveOutcome {
  final MovesModel move;
  final bool fromBook;
  final bool deliberateBlunder;
  final MoveAssessment? assessment;

  /// Human-like behaviors that shaped this move (for chat / post-game).
  final List<BehaviorNote> behaviors;

  const BotMoveOutcome({
    required this.move,
    required this.fromBook,
    required this.deliberateBlunder,
    this.assessment,
    this.behaviors = const [],
  });
}

/// The bot's brain. Owns the `genetom_chess_engine` instance (rules, board
/// state, game-over detection) and layers human-like play on top:
///
/// 1. Opening book (instant, human theory for the first plies).
/// 2. Time-boxed custom search (negamax + alpha-beta + MVV-LVA ordering +
///    quiescence) — legal moves always come from the engine.
/// 3. Human-error model: deliberate inaccuracies + rookie randomness.
/// 4. Instant greedy fallback (captures-first) — can never hang.
/// 5. Mercy: eases off when the human is getting crushed.
/// 6. Workarounds for known engine quirks (see docs/ENGINE_NOTES.md).
class ArenaBrain {
  ArenaBrain({
    required this.settings,
    required this.personality,
    Random? random,
  })  : _random = random ?? Random(),
        behavior = HumanBehaviorEngine(
          personality: personality,
          random: random ?? Random(),
        );

  final EngineSettings settings;
  final BotPersonality personality;

  /// Human-like behavior layer (delays, errors, resignation, offers).
  final HumanBehaviorEngine behavior;

  final Random _random;

  /// Per-game player tempo trait: some humans are simply quicker or slower
  /// players. Stable for the whole game so the bot has a consistent "style".
  late final double _paceTrait = 0.85 + _random.nextDouble() * 0.4;

  /// Live estimate of the human's own seconds-per-move (EMA, set by the
  /// controller). When known, the bot converges to the user's speed.
  double? humanPaceSec;

  ChessEngine? _engine;
  ArenaSearch? _search;
  final BlunderTracker tracker = BlunderTracker();
  final List<String> uciHistory = <String>[];

  ValueChanged<List<List<int>>>? onBoardChanged;
  ValueChanged<GameOver>? onGameOver;
  void Function(bool isWhitePawn, CellPosition position)? onPromotionNeeded;

  bool _mercyArmed = false;

  /// Gap (cp) between the search's best and 2nd-best root move from the last
  /// search — lets the behavior layer detect hesitation / forced recaptures.
  int _lastSpreadCp = 0;

  List<List<int>> get board =>
      _engine?.getBoardData() ?? List.generate(8, (_) => List<int>.filled(8, 0));

  void init() {
    tracker.reset();
    uciHistory.clear();
    _mercyArmed = false;
    final config = ChessConfig(
      isPlayerAWhite: true, // v1: human always White.
      difficulty: settings.fallbackDifficulty,
    );
    _engine = ChessEngine(
      config,
      boardChangeCallback: (b) {
        // Copy: the engine passes its internal mutable board.
        onBoardChanged?.call(ChessEval.copyBoard(b));
      },
      gameOverCallback: (g) {
        onGameOver?.call(g);
      },
      pawnPromotion: (isWhite, pos) {
        onPromotionNeeded?.call(isWhite, pos);
      },
    );
    _search = ArenaSearch(
      legalMovesFor: (b, p) {
        final e = _engine;
        if (e == null) return <CellPosition>[];
        return e.getValidMovesOfPeiceByPosition(b, p);
      },
    );
  }

  void dispose() {
    _engine = null;
    _search = null;
    onBoardChanged = null;
    onGameOver = null;
    onPromotionNeeded = null;
  }

  List<CellPosition> validMovesFor(CellPosition pos) {
    try {
      final e = _engine;
      if (e == null) return const [];
      return e.getValidMovesOfPeiceByPosition(e.getBoardData(), pos);
    } catch (_) {
      return const [];
    }
  }

  void setPromotion(CellPosition pos, ChessPiece piece) {
    try {
      _engine?.setPawnPromotion(pos, piece);
    } catch (_) {}
  }

  int whiteEvalCp() {
    try {
      return ChessEval.evaluateWhite(board).round();
    } catch (_) {
      return 0;
    }
  }

  /// Applies a human (White) move. Returns quality assessment for chat and
  /// post-game stats.
  HumanMoveOutcome playHumanMove(MovesModel move) {
    final e = _engine!;
    final before = e.getBoardData();
    final evalBefore = ChessEval.evaluateWhite(before).round();
    final captured = before[move.targetPosition.row][move.targetPosition.col];
    final uci = PieceGlyphs.uciFor(move);
    final isBook =
        OpeningBook.isKnownMove(historyUci: uciHistory, candidateUci: uci);

    e.movePiece(move);
    uciHistory.add(uci);

    final after = e.getBoardData();
    final evalAfter = ChessEval.evaluateWhite(after).round();
    final gaveCheck = ChessEval.isInCheck(after, false);
    final assessment = tracker.assess(
      evalBeforeMoverCp: evalBefore,
      evalAfterMoverCp: evalAfter,
      isBookMove: isBook,
      gaveCheck: gaveCheck,
      wasCapture: captured != 0,
      capturedValue: captured.abs(),
    );
    tracker.recordHuman(assessment);

    // Mercy: a struggling human gets a slightly kinder bot.
    if (!isBook && tracker.userBlunders >= 2 && evalAfter < -250) {
      _mercyArmed = true;
    }
    return HumanMoveOutcome(assessment: assessment, isBookMove: isBook);
  }

  /// Searches, pauses briefly for human-like pacing, then applies the bot
  /// (Black) move. Returns null only when the bot has no legal moves.
  ///
  /// [humanVerdict] and [moveEval] adjust the think-time window to simulate
  /// a real human: longer after blunders (exploitation pause), longer after
  /// brilliant moves (surprise), shorter on obvious recaptures.
  Future<BotMoveOutcome?> playBotMove({
    MoveVerdict? humanVerdict,
    int humanSwingCp = 0,
    bool wasCapture = false,
    int botClockSec = 999,
    int humanClockSec = 999,
    bool botInCheck = false,
  }) async {
    final e = _engine;
    if (e == null) return null;

    // Base think time: one draw from the human pacing model — exponential
    // spread keyed to the time control and the bot's rating, so weak bots
    // hesitate and snap like real beginners instead of metronome-moving.
    var thinkMs = HumanPace.sampleThinkMs(
      timeControl: settings.paceTimeControl,
      rating: settings.paceRating,
      random: _random,
      trait: _paceTrait,
      humanAvgSec: humanPaceSec,
    );

    // ── Human-like behavior layer ─────────────────────────────────────
    final boardNow = e.getBoardData();
    final plan = behavior.plan(BotMoveInput(
      state: BehaviorInput(
        moveCount: uciHistory.length,
        botClockSec: botClockSec,
        humanClockSec: humanClockSec,
        evalWhiteCp: ChessEval.evaluateWhite(boardNow).round(),
        lastHumanVerdict: humanVerdict,
        humanJustCaptured: wasCapture,
        botInCheck: botInCheck,
        searchSpreadCp: _lastSpreadCp,
        isEndgame: ChessEval.isEndgameBoard(boardNow),
      ),
    ));
    thinkMs += plan.thinkDeltaMs;

    // After a mistake: slight extra thought (kept from the classic model).
    if (humanVerdict == MoveVerdict.mistake) {
      thinkMs += 200 + _random.nextInt(300);
    }
    // Small random jitter to avoid robotic precision.
    thinkMs += _random.nextInt(150) - 75;
    if (thinkMs < 650) thinkMs = 650;

    final think = Future<void>.delayed(Duration(milliseconds: thinkMs));

    BotMoveOutcome? outcome;
    try {
      outcome = await _chooseBotMove(
        blunderMultiplier: plan.blunderMultiplier,
        depthPenalty: plan.depthPenalty,
      );
    } catch (_) {
      outcome = null;
    }
    await think;
    outcome ??= _greedyFallback(e);
    if (outcome == null) return null;

    final before = ChessEval.copyBoard(e.getBoardData());
    final evalBeforeBlack = -ChessEval.evaluateWhite(before).round();
    final captured = before[outcome.move.targetPosition.row]
        [outcome.move.targetPosition.col];

    e.movePiece(outcome.move);
    _promoteStrandedBlackPawns(e);
    uciHistory.add(PieceGlyphs.uciFor(outcome.move));

    final after = e.getBoardData();
    final evalAfterBlack = -ChessEval.evaluateWhite(after).round();
    final gaveCheck = ChessEval.isInCheck(after, true);
    final assessment = tracker.assess(
      evalBeforeMoverCp: evalBeforeBlack,
      evalAfterMoverCp: evalAfterBlack,
      isBookMove: outcome.fromBook,
      gaveCheck: gaveCheck,
      wasCapture: captured != 0,
      capturedValue: captured.abs(),
    );
    tracker.recordBot(assessment);
    behavior.observeBot(assessment);
    return BotMoveOutcome(
      move: outcome.move,
      fromBook: outcome.fromBook,
      deliberateBlunder: outcome.deliberateBlunder,
      assessment: assessment,
      behaviors: plan.notes,
    );
  }

  Future<BotMoveOutcome?> _chooseBotMove({
    double blunderMultiplier = 1.0,
    int depthPenalty = 0,
  }) async {
    final e = _engine;
    final search = _search;
    if (e == null || search == null) return null;
    // Let the "thinking" UI paint before the CPU-bound search starts.
    await Future<void>.delayed(Duration.zero);

    // 1) Opening book.
    if (uciHistory.length.isOdd) {
      final replyUci = OpeningBook.replyFor(
        historyUci: uciHistory,
        maxPly: settings.bookPly,
        random: _random,
        pool: OpeningBook.linesFor(personality),
      );
      if (replyUci != null) {
        final bookMove = PieceGlyphs.moveFromUci(replyUci);
        if (bookMove != null && _isLegal(e, bookMove)) {
          return BotMoveOutcome(
            move: bookMove,
            fromBook: true,
            deliberateBlunder: false,
          );
        }
      }
    }

    // 2) Time-boxed search (behavior layer may shave depth in the endgame).
    var depth = settings.maxDepth - depthPenalty;
    if (depth < 1) depth = 1;
    List<ScoredMove> scored = const [];
    try {
      scored = search.search(
        board: e.getBoardData(),
        whiteToMove: false,
        timeMs: settings.searchTimeMs,
        maxDepth: depth,
      );
    } catch (_) {
      scored = const [];
    }
    if (scored.length > 1) {
      _lastSpreadCp = (scored.first.score - scored[1].score).round().abs();
    } else {
      _lastSpreadCp = 0;
    }
    if (scored.isNotEmpty) {
      var blunderRate = settings.blunderRate * blunderMultiplier;
      if (_mercyArmed) {
        blunderRate += 0.08;
      }
      if (blunderRate > 0.45) blunderRate = 0.45;
      // Deliberate inaccuracy: pick a sane-but-suboptimal move.
      if (blunderRate > 0 &&
          _random.nextDouble() < blunderRate &&
          scored.length > 1) {
        final best = scored.first.score;
        final slack = settings.blunderSlackCp;
        final pool = scored.where((s) => best - s.score <= slack).toList();
        // Only vary among moves the search still considers plausible. If
        // there is no second candidate within the safety margin, play best.
        if (pool.length > 1) {
          final pickFrom = pool.skip(1).take(3).toList();
          final pick = pickFrom[_random.nextInt(pickFrom.length)];
          return BotMoveOutcome(
            move: pick.move,
            fromBook: false,
            deliberateBlunder: true,
          );
        }
      }
      return BotMoveOutcome(
        move: scored.first.move,
        fromBook: false,
        deliberateBlunder: false,
      );
    }

    // 3) Greedy fallback (instant, never hangs).
    return _greedyFallback(e);
  }

  bool _isLegal(ChessEngine e, MovesModel m) {
    try {
      final targets = e.getValidMovesOfPeiceByPosition(
        e.getBoardData(),
        m.currentPosition,
      );
      for (final t in targets) {
        if (t.row == m.targetPosition.row && t.col == m.targetPosition.col) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  BotMoveOutcome? _greedyFallback(ChessEngine e) {
    try {
      final board = e.getBoardData();
      MovesModel? best;
      var bestScore = -1000000000;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          final v = board[r][c];
          if (v >= 0) continue; // bot is Black
          final from = CellPosition(row: r, col: c);
          final targets = e.getValidMovesOfPeiceByPosition(board, from);
          for (final t in targets) {
            final victim = board[t.row][t.col].abs();
            var s = victim * 10 - v.abs() ~/ 16 + _random.nextInt(7);
            // Nudge toward the centre.
            s += 3 - (((3 - t.row).abs() + (3 - t.col).abs()) ~/ 2);
            if (s > bestScore) {
              bestScore = s;
              best = MovesModel(
                currentPosition: from,
                targetPosition: CellPosition(row: t.row, col: t.col),
              );
            }
          }
        }
      }
      if (best == null) return null;
      return BotMoveOutcome(
        move: best,
        fromBook: false,
        deliberateBlunder: false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Workaround: the engine's promotion check only recognises White pawns
  /// (`board[...] == pawnPower`), so Black pawns reaching the last rank would
  /// stay pawns forever. Auto-queen them here.
  void _promoteStrandedBlackPawns(ChessEngine e) {
    try {
      final board = e.getBoardData();
      for (var c = 0; c < 8; c++) {
        if (board[7][c] == -pawnPower) {
          e.setPawnPromotion(CellPosition(row: 7, col: c), ChessPiece.queen);
        }
      }
    } catch (_) {}
  }
}
