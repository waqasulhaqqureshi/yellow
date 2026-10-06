import 'package:flutter/material.dart';

import '../../../../core/theme/arena_theme.dart';
import '../../../../core/widgets/flag_avatar.dart';
import '../../../bot/domain/bot_profile.dart';
import '../../domain/game_result.dart';

/// End-of-game summary: gradient result header, overlapping player cards,
/// animated accuracy bars and a clean stat grid. Same public API as before.
class GameOverDialog extends StatelessWidget {
  final BotProfile bot;
  final GameResult result;
  final String title;
  final String subtitle;
  final String humanName;
  final String humanAvatarSeed;
  final int eloDelta;
  final int newRating;
  final int moves;
  final String difficultyLabel;
  final int difficultyPoints;
  final int? humanAccuracy;
  final int? botAccuracy;
  final int humanMoves;
  final int botMoves;
  final int blunders;
  final int mistakes;
  final int inaccuracies;
  final int checks;
  final int botBlunders;
  final int botMistakes;
  final int botInaccuracies;
  final int botChecks;
  final VoidCallback onReview;
  final VoidCallback onNewOpponent;
  final VoidCallback onHome;

  const GameOverDialog({
    super.key,
    required this.bot,
    required this.result,
    required this.title,
    required this.subtitle,
    required this.humanName,
    required this.humanAvatarSeed,
    required this.eloDelta,
    required this.newRating,
    required this.moves,
    required this.difficultyLabel,
    required this.difficultyPoints,
    required this.humanAccuracy,
    required this.botAccuracy,
    required this.humanMoves,
    required this.botMoves,
    required this.blunders,
    required this.mistakes,
    required this.inaccuracies,
    required this.checks,
    required this.botBlunders,
    required this.botMistakes,
    required this.botInaccuracies,
    required this.botChecks,
    required this.onReview,
    required this.onNewOpponent,
    required this.onHome,
  });

  static Future<void> show(
    BuildContext context, {
    required BotProfile bot,
    required GameResult result,
    required String title,
    required String subtitle,
    required String humanName,
    required String humanAvatarSeed,
    required int eloDelta,
    required int newRating,
    required int moves,
    required String difficultyLabel,
    required int difficultyPoints,
    required int? humanAccuracy,
    required int? botAccuracy,
    required int humanMoves,
    required int botMoves,
    required int blunders,
    required int mistakes,
    required int inaccuracies,
    required int checks,
    required int botBlunders,
    required int botMistakes,
    required int botInaccuracies,
    required int botChecks,
    required VoidCallback onReview,
    required VoidCallback onNewOpponent,
    required VoidCallback onHome,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => GameOverDialog(
        bot: bot,
        result: result,
        title: title,
        subtitle: subtitle,
        humanName: humanName,
        humanAvatarSeed: humanAvatarSeed,
        eloDelta: eloDelta,
        newRating: newRating,
        moves: moves,
        difficultyLabel: difficultyLabel,
        difficultyPoints: difficultyPoints,
        humanAccuracy: humanAccuracy,
        botAccuracy: botAccuracy,
        humanMoves: humanMoves,
        botMoves: botMoves,
        blunders: blunders,
        mistakes: mistakes,
        inaccuracies: inaccuracies,
        checks: checks,
        botBlunders: botBlunders,
        botMistakes: botMistakes,
        botInaccuracies: botInaccuracies,
        botChecks: botChecks,
        onReview: onReview,
        onNewOpponent: onNewOpponent,
        onHome: onHome,
      ),
    );
  }

  Color get _resultColor => result == GameResult.win
      ? const Color(0xFF1E9E63)
      : result == GameResult.draw
          ? const Color(0xFF4D6C81)
          : const Color(0xFFC4474F);

  IconData get _resultIcon => result == GameResult.win
      ? Icons.emoji_events_rounded
      : result == GameResult.draw
          ? Icons.handshake_rounded
          : Icons.flag_rounded;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFBFDFF), Color(0xFFF2F7FF)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 14)),
              ],
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(decoration: TextDecoration.none),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(),
                    // Overlapping player + delta card.
                    Transform.translate(
                      offset: const Offset(0, -34),
                      child: _playerCard(),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _accuracyBlock(),
                          const SizedBox(height: 14),
                          _statGrid(),
                          const SizedBox(height: 18),
                          _buttons(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      decoration: BoxDecoration(
        color: _resultColor.withValues(alpha: 0.10),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: _resultColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Icon(_resultIcon, color: _resultColor, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _resultColor,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _playerCard() {
    final deltaText = eloDelta > 0 ? '+$eloDelta' : '$eloDelta';
    final deltaColor = eloDelta > 0
        ? const Color(0xFF1E9E63)
        : eloDelta < 0
            ? const Color(0xFFC4474F)
            : const Color(0xFF4D6C81);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Color(0x2A000000), blurRadius: 16, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _player(humanAvatarSeed, humanName, 'PK')),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: deltaColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  deltaText,
                  style: TextStyle(
                    color: deltaColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'rating',
                  style: TextStyle(color: Color(0xFF8A97A5), fontSize: 9),
                ),
              ],
            ),
          ),
          Expanded(child: _player(bot.avatarSeed, bot.name, bot.countryIso)),
        ],
      ),
    );
  }

  Widget _player(String seed, String name, String iso) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            BotAvatar(seed: seed, size: 52),
            Positioned(
              right: -4,
              bottom: -2,
              child: CountryFlag(isoCode: iso, width: 22, height: 15),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2B3B49),
          ),
        ),
      ],
    );
  }

  Widget _accuracyBlock() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _accuracyRow(humanName, humanAccuracy, const Color(0xFF1E9E63)),
          const SizedBox(height: 10),
          _accuracyRow(bot.name, botAccuracy, const Color(0xFF4D6C81)),
        ],
      ),
    );
  }

  Widget _accuracyRow(String name, int? value, Color color) {
    final v = (value ?? 0).clamp(0, 100).toDouble();
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF33465A)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: v / 100,
              minHeight: 8,
              backgroundColor: const Color(0xFFDEE5EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            value == null ? '—' : '$value%',
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF33465A)),
          ),
        ),
      ],
    );
  }

  Widget _statGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _statChip('Moves', '$humanMoves', '$botMoves'),
        _statChip('Blunders', '$blunders', '$botBlunders'),
        _statChip('Mistakes', '$mistakes', '$botMistakes'),
        _statChip('Checks', '$checks', '$botChecks'),
        _statChip('Rating', '$newRating', '${bot.rating}'),
      ],
    );
  }

  Widget _statChip(String label, String human, String bot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(human, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E9E63), fontSize: 12)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFF718096), fontSize: 11)),
          const SizedBox(width: 6),
          Text(bot, style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF4D6C81), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buttons(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: ArenaTheme.orangeGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onNewOpponent,
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Play again',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onHome,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF33465A),
                  side: const BorderSide(color: Color(0xFFD8E0E7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Home'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: onReview,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF33465A),
                  side: const BorderSide(color: Color(0xFFD8E0E7)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('Review'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
