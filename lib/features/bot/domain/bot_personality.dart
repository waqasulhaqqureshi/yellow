/// Bot character. Drives chat flavour, chat frequency and opening attitude.
enum BotPersonality { aggressive, positional, trickster, calm, showman }

extension BotPersonalityX on BotPersonality {
  String get label {
    switch (this) {
      case BotPersonality.aggressive:
        return 'Aggressive';
      case BotPersonality.positional:
        return 'Positional';
      case BotPersonality.trickster:
        return 'Trickster';
      case BotPersonality.calm:
        return 'Calm';
      case BotPersonality.showman:
        return 'Showman';
    }
  }

  String get tagline {
    switch (this) {
      case BotPersonality.aggressive:
        return 'Attacks first, asks later';
      case BotPersonality.positional:
        return 'Slow squeeze, no mercy';
      case BotPersonality.trickster:
        return 'Traps in every opening';
      case BotPersonality.calm:
        return 'Quiet board, loud results';
      case BotPersonality.showman:
        return 'Here for the highlights';
    }
  }

  /// Probability that a game event triggers a chat line.
  double get chatFrequency {
    switch (this) {
      case BotPersonality.aggressive:
        return 0.45;
      case BotPersonality.positional:
        return 0.30;
      case BotPersonality.trickster:
        return 0.65;
      case BotPersonality.calm:
        return 0.22;
      case BotPersonality.showman:
        return 0.80;
    }
  }

  Duration get chatCooldown {
    switch (this) {
      case BotPersonality.aggressive:
        return const Duration(seconds: 12);
      case BotPersonality.positional:
        return const Duration(seconds: 18);
      case BotPersonality.trickster:
        return const Duration(seconds: 10);
      case BotPersonality.calm:
        return const Duration(seconds: 22);
      case BotPersonality.showman:
        return const Duration(seconds: 8);
    }
  }
}
