import 'package:flutter/material.dart';

import '../../../../core/theme/arena_theme.dart';
import '../../../../core/widgets/chess_piece_image.dart';
import '../../../../core/widgets/flag_avatar.dart';

/// Compact identity/clock strip surrounding the board.
class PlayerBar extends StatelessWidget {
  final String name;
  final String detail;
  final String avatarSeed;
  final String? isoCode;
  final List<int> captured;
  final String? scoreText;
  final bool active;
  final bool thinking;
  final bool inCheck;
  final bool human;
  final String clockText;
  final String pieceStyle;

  /// Under 20 seconds: clock pulses red (low-clock drama).
  final bool lowClock;
  final bool pulse;

  /// Theme-derived bar colours so the strip matches the board theme.
  final Color? barTop;
  final Color? barBottom;

  const PlayerBar({
    super.key,
    required this.name,
    required this.detail,
    required this.avatarSeed,
    this.isoCode,
    this.captured = const [],
    this.scoreText,
    this.active = false,
    this.thinking = false,
    this.inCheck = false,
    this.human = false,
    this.clockText = '05:00',
    this.pieceStyle = 'modern',
    this.lowClock = false,
    this.pulse = false,
    this.barTop,
    this.barBottom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
      decoration: BoxDecoration(
        gradient: human && active
            ? const LinearGradient(
                colors: [Color(0xFFD07A00), Color(0xFF9E5300)],
              )
            : LinearGradient(
                colors: [
                  barTop ?? const Color(0xFF65351F),
                  barBottom ?? const Color(0xFF3D2117),
                ],
              ),
        border: Border(
          bottom: BorderSide(color: active ? ArenaTheme.gold : Colors.black54, width: 2),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: active ? ArenaTheme.goldLight : ArenaTheme.ink,
                    width: 2,
                  ),
                ),
                child: BotAvatar(seed: avatarSeed, size: 48),
              ),
              if (isoCode != null)
                Positioned(
                  right: -5,
                  bottom: -1,
                  child: CountryFlag(isoCode: isoCode!, width: 25, height: 17),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        human ? '$name (You)' : name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      detail,
                      style: const TextStyle(color: Color(0xFFD9B69A), fontSize: 11),
                    ),
                    if (inCheck) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ArenaTheme.danger,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Text(
                          'CHECK',
                          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    const Text('◷', style: TextStyle(color: Colors.white, fontSize: 20)),
                    const SizedBox(width: 5),
                    Text(
                      clockText,
                      style: TextStyle(
                        color: lowClock
                            ? (pulse
                                ? const Color(0xFFFF3B3B)
                                : const Color(0xFFB31212))
                            : active
                                ? human
                                    ? const Color(0xFFFFD35A)
                                    : const Color(0xFF6DDC7C)
                                : const Color(0xFFD9B69A),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (thinking) ...[
                      const SizedBox(width: 7),
                      const Text(
                        '…',
                        style: TextStyle(
                          color: Color(0xFFD9B69A),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                    if (scoreText != null) ...[
                      const SizedBox(width: 7),
                      Text(
                        scoreText!,
                        style: const TextStyle(color: ArenaTheme.goldLight, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (captured.isNotEmpty) _capturedStrip(),
        ],
      ),
    );
  }

  Widget _capturedStrip() {
    final show = captured.length > 6 ? captured.sublist(0, 6) : captured;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 110),
      child: Wrap(
        spacing: -2,
        runSpacing: -4,
        alignment: WrapAlignment.end,
        children: [
          for (final value in show)
            SizedBox(
              width: 20,
              height: 20,
              child: ChessPieceImage(value: value, style: pieceStyle),
            ),
          if (captured.length > show.length)
            Text(
              '+${captured.length - show.length}',
              style: const TextStyle(color: ArenaTheme.muted, fontSize: 10),
            ),
        ],
      ),
    );
  }
}
