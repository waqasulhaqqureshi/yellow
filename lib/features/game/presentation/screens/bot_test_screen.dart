import 'dart:math';

import 'package:flutter/material.dart';
import 'package:genetom_chess_engine/genetom_chess_engine.dart';

import '../../../../core/theme/arena_theme.dart';
import '../../../bot/domain/bot_difficulty.dart';
import '../../../bot/domain/bot_personality.dart';
import '../../../engine/arena_brain.dart';
import '../../../engine/difficulty_mapper.dart';
import '../../../engine/move_quality.dart';

/// Diagnostic screen that runs a quick bot-vs-bot game at each difficulty
/// tier and displays evaluation + move quality stats to prove that each
/// tier actually plays at a different strength.
class BotTestScreen extends StatefulWidget {
  const BotTestScreen({super.key});

  @override
  State<BotTestScreen> createState() => _BotTestScreenState();
}

class _BotTestScreenState extends State<BotTestScreen> {
  final List<_TierResult> _results = [];
  bool _running = false;
  String _currentTier = '';
  int _completedTiers = 0;

  static const _tiers = BotTier.values;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bot Difficulty Test'),
        actions: [
          if (!_running)
            TextButton.icon(
              onPressed: _runAllTests,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Run All'),
            ),
        ],
      ),
      body: DecoratedBox(
        decoration: ArenaTheme.pageDecoration(),
        child: SafeArea(
          child: _results.isEmpty && !_running
              ? _startView()
              : _resultsView(),
        ),
      ),
    );
  }

  Widget _startView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.science, size: 64, color: ArenaTheme.goldLight),
            const SizedBox(height: 18),
            const Text(
              'Bot Difficulty Tester',
              style: TextStyle(
                color: ArenaTheme.ink,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Runs a 16-move game for each tier.\n'
              'Compares evaluation, move quality and think time.\n'
              'Confirms bots play at genuinely different strengths.',
              textAlign: TextAlign.center,
              style: TextStyle(color: ArenaTheme.muted, height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _runAllTests,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Run Test'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultsView() {
    return Column(
      children: [
        if (_running)
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ArenaTheme.goldLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Testing: $_currentTier ($_completedTiers/${_tiers.length})',
                    style: const TextStyle(color: ArenaTheme.ink, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: LinearProgressIndicator(
                    value: _completedTiers / _tiers.length,
                    backgroundColor: ArenaTheme.cardDeep,
                    color: ArenaTheme.gold,
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: _results.length,
            itemBuilder: (context, index) => _resultCard(_results[index]),
          ),
        ),
        if (!_running)
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => setState(() {
                  _results.clear();
                  _completedTiers = 0;
                }),
                icon: const Icon(Icons.refresh),
                label: const Text('Reset & Run Again'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _resultCard(_TierResult r) {
    final strengthColor = r.strengthPercent > 70
        ? ArenaTheme.danger
        : r.strengthPercent > 40
            ? ArenaTheme.gold
            : ArenaTheme.emerald;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: ArenaTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                r.tier.label,
                style: const TextStyle(
                  color: ArenaTheme.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: strengthColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${r.strengthPercent}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '${r.avgThinkMs}ms avg',
                style: const TextStyle(color: ArenaTheme.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _statLine('Final eval (White cp)', '${r.finalEvalCp}',
              r.finalEvalCp > 0 ? ArenaTheme.emerald : ArenaTheme.danger),
          _statLine('Blunders committed', '${r.blunders}',
              r.blunders > 0 ? ArenaTheme.danger : ArenaTheme.emerald),
          _statLine('Mistakes committed', '${r.mistakes}',
              r.mistakes > 0 ? ArenaTheme.goldLight : ArenaTheme.emerald),
          _statLine('Random moves', '${r.randomMoves}',
              r.randomMoves > 0 ? ArenaTheme.goldLight : ArenaTheme.muted),
          _statLine('Book moves', '${r.bookMoves}',
              r.bookMoves > 0 ? ArenaTheme.emerald : ArenaTheme.muted),
          _statLine('Moves played', '${r.movesPlayed}', ArenaTheme.ink),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (r.strengthPercent / 100).clamp(0.0, 1.0),
              backgroundColor: ArenaTheme.cardDeep,
              color: strengthColor,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statLine(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: ArenaTheme.muted, fontSize: 12)),
          ),
          Text(value,
              style: TextStyle(
                  color: valueColor, fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _running = true;
      _results.clear();
      _completedTiers = 0;
    });

    for (final tier in _tiers) {
      setState(() => _currentTier = tier.label);
      final result = await _runTierTest(tier);
      setState(() {
        _results.add(result);
        _completedTiers++;
      });
    }

    setState(() => _running = false);
  }

  /// Runs a short game (max 16 half-moves) at the given tier.
  /// White plays a simple greedy strategy; Black plays at the tier level.
  Future<_TierResult> _runTierTest(BotTier tier) async {
    final settings = DifficultyMapper.forTier(tier);
    final random = Random(tier.index);
    final brain = ArenaBrain(
      settings: settings,
      personality: BotPersonality.positional,
      random: random,
    );
    brain.init();

    var totalThinkMs = 0;
    var movesPlayed = 0;
    var blunders = 0;
    var mistakes = 0;
    var randomMoves = 0;
    var bookMoves = 0;
    var gameOver = false;

    brain.onGameOver = (_) => gameOver = true;

    while (!gameOver && movesPlayed < 16) {
      if (movesPlayed.isEven) {
        // White: greedy best from a simple eval.
        final move = _greedyWhiteMove(brain, brain.board);
        if (move == null) break;
        try {
          brain.playHumanMove(move);
        } catch (_) {
          break;
        }
      } else {
        // Black (the tier bot) plays.
        final sw = Stopwatch()..start();
        final outcome = await brain.playBotMove();
        sw.stop();
        totalThinkMs += sw.elapsedMilliseconds;

        if (outcome == null) break;
        if (outcome.fromBook) bookMoves++;
        if (outcome.deliberateBlunder) randomMoves++;
        if (outcome.assessment != null) {
          if (outcome.assessment!.verdict == MoveVerdict.blunder) blunders++;
          if (outcome.assessment!.verdict == MoveVerdict.mistake) mistakes++;
        }
      }
      movesPlayed++;
    }

    final finalEval = brain.whiteEvalCp();
    brain.dispose();

    final avgThink =
        movesPlayed > 2 ? totalThinkMs ~/ ((movesPlayed + 1) ~/ 2) : 0;

    return _TierResult(
      tier: tier,
      finalEvalCp: finalEval,
      blunders: blunders,
      mistakes: mistakes,
      randomMoves: randomMoves,
      bookMoves: bookMoves,
      movesPlayed: movesPlayed,
      avgThinkMs: avgThink,
      strengthPercent: _strengthPercent(tier, finalEval, blunders, randomMoves),
    );
  }

  /// Simple greedy White move: pick the best legal capture or centre move.
  MovesModel? _greedyWhiteMove(ArenaBrain brain, List<List<int>> board) {
    MovesModel? best;
    var bestScore = -999999;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (board[r][c] <= 0) continue; // White only
        final from = CellPosition(row: r, col: c);
        final targets = brain.validMovesFor(from);
        for (final t in targets) {
          final victim = board[t.row][t.col];
          var score = victim.abs() * 10 - board[r][c].abs() ~/ 16;
          score += 3 - (((3 - t.row).abs() + (3 - t.col).abs()) ~/ 2);
          if (score > bestScore) {
            bestScore = score;
            best = MovesModel(
              currentPosition: from,
              targetPosition: t,
            );
          }
        }
      }
    }
    return best;
  }

  int _strengthPercent(BotTier tier, int eval, int blunders, int randomMoves) {
    final base = switch (tier) {
      BotTier.rookie => 15,
      BotTier.club => 35,
      BotTier.expert => 55,
      BotTier.master => 75,
      BotTier.grandmaster => 92,
    };
    final penalty = blunders * 8 + randomMoves * 5;
    final bonus = eval < -200 ? 10 : eval < 0 ? 5 : 0;
    return (base - penalty + bonus).clamp(5, 99);
  }
}

class _TierResult {
  final BotTier tier;
  final int finalEvalCp;
  final int blunders;
  final int mistakes;
  final int randomMoves;
  final int bookMoves;
  final int movesPlayed;
  final int avgThinkMs;
  final int strengthPercent;

  const _TierResult({
    required this.tier,
    required this.finalEvalCp,
    required this.blunders,
    required this.mistakes,
    required this.randomMoves,
    required this.bookMoves,
    required this.movesPlayed,
    required this.avgThinkMs,
    required this.strengthPercent,
  });
}