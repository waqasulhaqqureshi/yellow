/// Strength tier. Used for both bots and the human player's label.
enum BotTier { rookie, club, expert, master, grandmaster }

extension BotTierX on BotTier {
  String get label {
    switch (this) {
      case BotTier.rookie:
        return 'Rookie';
      case BotTier.club:
        return 'Club Player';
      case BotTier.expert:
        return 'Expert';
      case BotTier.master:
        return 'Master';
      case BotTier.grandmaster:
        return 'Grandmaster';
    }
  }
}

class BotTiering {
  BotTiering._();

  static BotTier tierForRating(int rating) {
    if (rating < 950) return BotTier.rookie;
    if (rating < 1150) return BotTier.club;
    if (rating < 1400) return BotTier.expert;
    if (rating < 1700) return BotTier.master;
    return BotTier.grandmaster;
  }

  /// Fun FIDE-style title for strong bots.
  static String titleForRating(int rating) {
    if (rating >= 2000) return 'GM';
    if (rating >= 1800) return 'IM';
    if (rating >= 1600) return 'NM';
    return '';
  }
}
