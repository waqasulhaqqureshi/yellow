import 'package:flutter/material.dart';

import 'arena_theme.dart';

/// Metadata for one colour theme.
class ArenaThemeOption {
  final ArenaThemeId id;
  final String name;
  final String emoji;
  final Color primary;
  final Color accent;

  const ArenaThemeOption({
    required this.id,
    required this.name,
    required this.emoji,
    required this.primary,
    required this.accent,
  });
}

/// All available themes.
const arenaThemes = [
  ArenaThemeOption(
    id: ArenaThemeId.chessCom,
    name: 'Chess.com Blue',
    emoji: '♟️',
    primary: Color(0xFF0076DA),
    accent: Color(0xFFFF8C00),
  ),
  ArenaThemeOption(
    id: ArenaThemeId.classic,
    name: 'Classic Arena',
    emoji: '🪵',
    primary: Color(0xFF102F3F),
    accent: Color(0xFFF39A18),
  ),
  ArenaThemeOption(
    id: ArenaThemeId.midnight,
    name: 'Midnight',
    emoji: '🌙',
    primary: Color(0xFF0D1117),
    accent: Color(0xFF58A6FF),
  ),
  ArenaThemeOption(
    id: ArenaThemeId.forest,
    name: 'Forest',
    emoji: '🌲',
    primary: Color(0xFF1A2F1A),
    accent: Color(0xFF6BCB77),
  ),
  ArenaThemeOption(
    id: ArenaThemeId.royal,
    name: 'Royal Purple',
    emoji: '👑',
    primary: Color(0xFF1A0A2E),
    accent: Color(0xFFBB86FC),
  ),
  ArenaThemeOption(
    id: ArenaThemeId.ocean,
    name: 'Deep Ocean',
    emoji: '🌊',
    primary: Color(0xFF0A1628),
    accent: Color(0xFF00BCD4),
  ),
];

/// Holds the active theme. Attach to the widget tree above [MaterialApp].
class ThemeProvider extends ChangeNotifier {
  ArenaThemeId _current = ArenaThemeId.chessCom;

  ArenaThemeId get current => _current;
  ArenaThemeOption get currentOption =>
      arenaThemes.firstWhere((t) => t.id == _current);

  void setTheme(ArenaThemeId id) {
    if (_current == id) return;
    _current = id;
    ArenaTheme.setTheme(id);
    notifyListeners();
  }
}