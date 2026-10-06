import 'package:flutter/material.dart';

import '../utils/piece_glyphs.dart';

/// Warms the asset cache for every bundled piece so the board's first paint
/// (and the first capture / promotion) shows real art instead of the glyph
/// errorBuilder. Failures are swallowed — a missing asset simply falls back.
class PieceAssetPreloader {
  PieceAssetPreloader._();

  static bool _done = false;

  static Future<void> warm(BuildContext context) async {
    if (_done) return;
    _done = true;
    final paths = <String>[
      ...PieceGlyphs.modernAssetPaths(),
      ...PieceGlyphs.classicAssetPaths(),
    ];
    await Future.wait<void>([
      for (final path in paths) _safe(path, context),
    ]);
  }

  static Future<void> _safe(String path, BuildContext context) async {
    try {
      await precacheImage(Image.asset(path).image, context);
    } catch (_) {
      // Never let a missing asset break startup; the glyph fallback applies.
    }
  }
}

/// Renders one of the bundled white chess-piece silhouettes.
///
/// The source pack only provides White pieces. Black is generated at paint
/// time with a full RGB inversion matrix, preserving transparency and avoiding
/// a second duplicated asset set.
class ChessPieceImage extends StatelessWidget {
  final int value;
  final double? size;
  final BoxFit fit;
  final String style;

  const ChessPieceImage({
    super.key,
    required this.value,
    this.size,
    this.fit = BoxFit.contain,
    this.style = 'modern',
  });

  static const ColorFilter _invert = ColorFilter.matrix(<double>[
    -1, 0, 0, 0, 255,
    0, -1, 0, 0, 255,
    0, 0, -1, 0, 255,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    if (value == 0) return const SizedBox.shrink();
    final modern = style != 'classic';
    final asset = PieceGlyphs.assetFor(value, modern: modern);
    final image = Image.asset(
      asset,
      width: size,
      height: size,
      fit: fit,
      filterQuality: FilterQuality.high,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => FittedBox(
        fit: BoxFit.contain,
        child: Text(
          PieceGlyphs.glyphFor(value),
          style: TextStyle(
            color: value > 0 ? Colors.white : Colors.black,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 2)],
          ),
        ),
      ),
    );
    return Semantics(
      image: true,
      label: '${value > 0 ? 'White' : 'Black'} ${PieceGlyphs.nameFor(value)}',
      child: !modern && value < 0
          ? ColorFiltered(colorFilter: _invert, child: image)
          : image,
    );
  }
}
