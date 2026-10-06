import 'package:flutter/material.dart';

class BoardThemeOption {
  final String id;
  final String name;
  final Color lightSquare;
  final Color darkSquare;

  const BoardThemeOption({
    required this.id,
    required this.name,
    required this.lightSquare,
    required this.darkSquare,
  });
}

const boardThemes = <BoardThemeOption>[
  BoardThemeOption(
    id: 'wood',
    name: 'Warm wood',
    lightSquare: Color(0xFFC18A64),
    darkSquare: Color(0xFF78422F),
  ),
  BoardThemeOption(
    id: 'classic',
    name: 'Classic green',
    lightSquare: Color(0xFFEEEED2),
    darkSquare: Color(0xFF769656),
  ),
  BoardThemeOption(
    id: 'slate',
    name: 'Slate',
    lightSquare: Color(0xFFDCE4E9),
    darkSquare: Color(0xFF748896),
  ),
  BoardThemeOption(
    id: 'midnight',
    name: 'Midnight',
    lightSquare: Color(0xFFB6C4D2),
    darkSquare: Color(0xFF48566A),
  ),
];

BoardThemeOption boardThemeFor(String id) => boardThemes.firstWhere(
      (theme) => theme.id == id,
      orElse: () => boardThemes.first,
    );

/// Chrome colours derived from the board theme so the app bar, body
/// surround and player bars always match the chosen squares (wood stays
/// wood, green goes green, slate goes slate).
extension BoardThemeChrome on BoardThemeOption {
  /// Three harmonised stops (top, mid, bottom) for gradients.
  List<Color> get chromeStops {
    final hsl = HSLColor.fromColor(darkSquare);
    return [
      hsl.withLightness((hsl.lightness * 0.82).clamp(0.06, 0.92)).toColor(),
      darkSquare,
      hsl.withLightness((hsl.lightness * 0.55).clamp(0.04, 0.9)).toColor(),
    ];
  }

  LinearGradient get chromeGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: chromeStops,
      );
}
