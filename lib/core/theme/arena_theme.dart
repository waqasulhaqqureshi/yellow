import 'package:flutter/material.dart';

/// Identifies a colour theme for the arena UI.
enum ArenaThemeId { chessCom, classic, midnight, forest, royal, ocean }

/// Visual system based on the chess.com-style reference.
///
/// The palette lives in one place so every route stays consistent.
/// Key colours are mutable: call [setTheme] to swap the entire palette
/// at runtime without restarting the app.
class ArenaTheme {
  ArenaTheme._();

  // ── Mutable palette — updated by [setTheme] ─────────────────────────
  static Color bg = const Color(0xFFF0F5FA);
  static Color bgSoft = const Color(0xFFE8EFF6);
  static Color card = const Color(0xFFFFFFFF);
  static Color cardDeep = const Color(0xFF1A3A5C);
  static Color line = const Color(0xFFD0DDE8);

  // ── Fixed accents ───────────────────────────────────────────────────
  static const Color gold = Color(0xFFF39A18);
  static const Color goldLight = Color(0xFFFFB341);
  static const Color emerald = Color(0xFF58D27E);
  static const Color danger = Color(0xFFCF3151);
  static const Color ink = Color(0xFF1A1A2E);
  static const Color muted = Color(0xFF6B8A99);

  // chess.com blue accent
  static const Color chessBlue = Color(0xFF0076DA);
  static const Color chessBlueDark = Color(0xFF005BA1);
  static const Color chessBlueLight = Color(0xFF4A9EE8);
  // Orange for CTA buttons
  static const Color ctaOrange = Color(0xFFFF8C00);
  static const Color ctaOrangeLight = Color(0xFFFFA940);

  // ── Gradients (rebuilt on theme change) ─────────────────────────────
  static LinearGradient pageGradient = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8EFF6), Color(0xFFF0F5FA), Color(0xFFF5F8FB)],
    stops: [0, 0.46, 1],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [ctaOrangeLight, ctaOrange],
  );

  static const LinearGradient blueGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [chessBlueLight, chessBlue, chessBlueDark],
  );

  static const LinearGradient woodGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF733823), Color(0xFF9A4A2B), Color(0xFF552615)],
  );

  // ── Board colours (warm wood — shared by all themes) ────────────────
  static const Color lightSquare = Color(0xFFC18A64);
  static const Color darkSquare = Color(0xFF78422F);
  static const Color selectSquare = Color(0xFFFFAD1F);
  static const Color lastMoveLight = Color(0xFFE0A24B);
  static const Color lastMoveDark = Color(0xFFB56A28);
  static const Color checkSquare = Color(0xFFD9483F);

  // ── Theme switching ─────────────────────────────────────────────────

  /// Swap the entire colour palette for [id].
  static void setTheme(ArenaThemeId id) {
    switch (id) {
      case ArenaThemeId.chessCom:
        bg = const Color(0xFFF0F5FA);
        bgSoft = const Color(0xFFE8EFF6);
        card = const Color(0xFFFFFFFF);
        cardDeep = const Color(0xFF1A3A5C);
        line = const Color(0xFFD0DDE8);
        pageGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE8EFF6), Color(0xFFF0F5FA), Color(0xFFF5F8FB)],
          stops: [0, 0.46, 1],
        );
      case ArenaThemeId.classic:
        bg = const Color(0xFF102F3F);
        bgSoft = const Color(0xFF173E50);
        card = const Color(0xFF2E687F);
        cardDeep = const Color(0xFF214F63);
        line = const Color(0xFF6391A3);
        pageGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3E7E96), Color(0xFF2A6379), Color(0xFF102F3F)],
          stops: [0, 0.46, 1],
        );
      case ArenaThemeId.midnight:
        bg = const Color(0xFF0D1117);
        bgSoft = const Color(0xFF161B22);
        card = const Color(0xFF21262D);
        cardDeep = const Color(0xFF161B22);
        line = const Color(0xFF30363D);
        pageGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF161B22), Color(0xFF0D1117), Color(0xFF010409)],
          stops: [0, 0.46, 1],
        );
      case ArenaThemeId.forest:
        bg = const Color(0xFF1A2F1A);
        bgSoft = const Color(0xFF223522);
        card = const Color(0xFF2D4A2D);
        cardDeep = const Color(0xFF1E3A1E);
        line = const Color(0xFF4A7A4A);
        pageGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2D5A2D), Color(0xFF1E3F1E), Color(0xFF0F1F0F)],
          stops: [0, 0.46, 1],
        );
      case ArenaThemeId.royal:
        bg = const Color(0xFF1A0A2E);
        bgSoft = const Color(0xFF251540);
        card = const Color(0xFF3D1F6D);
        cardDeep = const Color(0xFF2A1050);
        line = const Color(0xFF6B3FA0);
        pageGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3D1F6D), Color(0xFF2A1050), Color(0xFF120620)],
          stops: [0, 0.46, 1],
        );
      case ArenaThemeId.ocean:
        bg = const Color(0xFF0A1628);
        bgSoft = const Color(0xFF0F1F35);
        card = const Color(0xFF152D4A);
        cardDeep = const Color(0xFF0E1E35);
        line = const Color(0xFF2A5080);
        pageGradient = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF15304A), Color(0xFF0E2035), Color(0xFF050E18)],
          stops: [0, 0.46, 1],
        );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  static BoxDecoration pageDecoration() => BoxDecoration(
        gradient: pageGradient,
      );

  static BoxDecoration glassCard({double radius = 18}) => BoxDecoration(
        color: card.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: line.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      );

  static ThemeData dark() {
    final isLight = bg.computeLuminance() > 0.3;
    final scheme = ColorScheme.fromSeed(
      seedColor: chessBlue,
      brightness: isLight ? Brightness.light : Brightness.dark,
    ).copyWith(
      primary: chessBlue,
      secondary: emerald,
      surface: card,
      error: danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: isLight ? const Color(0xFF1A3A5C) : const Color(0xFF3D2117),
        foregroundColor: isLight ? Colors.white : ink,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: chessBlue,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: isLight ? ink : ink,
          side: BorderSide(color: isLight ? line : line),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: bgSoft,
        labelStyle: TextStyle(color: ink),
        side: BorderSide(color: line),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        modalBackgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isLight ? const Color(0xFF1A3A5C) : cardDeep,
        contentTextStyle: TextStyle(color: isLight ? Colors.white : ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: ink),
        bodyMedium: TextStyle(color: ink),
        bodySmall: TextStyle(color: muted),
        titleLarge: TextStyle(color: ink, fontWeight: FontWeight.w900),
        titleMedium: TextStyle(color: ink, fontWeight: FontWeight.w800),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : const Color(0xFF0B2431),
        selectedItemColor: chessBlue,
        unselectedItemColor: muted,
      ),
    );
  }
}