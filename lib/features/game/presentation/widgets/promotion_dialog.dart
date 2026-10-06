import 'package:flutter/material.dart';
import 'package:genetom_chess_engine/genetom_chess_engine.dart';

import '../../../../core/theme/arena_theme.dart';
import '../../../../core/widgets/chess_piece_image.dart';

/// Pawn promotion picker. Non-dismissible: the game waits for the choice.
class PromotionDialog extends StatelessWidget {
  final void Function(ChessPiece piece) onPick;

  const PromotionDialog({super.key, required this.onPick});

  static Future<void> show(
    BuildContext context,
    void Function(ChessPiece piece) onPick,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PromotionDialog(onPick: onPick),
    );
  }

  @override
  Widget build(BuildContext context) {
    const options = [
      (ChessPiece.queen, queenPower, 'Queen'),
      (ChessPiece.rook, rookPower, 'Rook'),
      (ChessPiece.bishop, bishopPower, 'Bishop'),
      (ChessPiece.horse, horsePower, 'Knight'),
    ];
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: ArenaTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Promote to',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ArenaTheme.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final (piece, value, label) in options)
              _option(context, piece, value, label),
          ],
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context,
    ChessPiece piece,
    int value,
    String label,
  ) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onPick(piece);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: ArenaTheme.bgSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ArenaTheme.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: ChessPieceImage(value: value),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: ArenaTheme.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
