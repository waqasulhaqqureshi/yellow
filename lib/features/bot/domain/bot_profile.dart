import 'bot_difficulty.dart';
import 'bot_personality.dart';

/// A generated CPU opponent: name, flag, avatar seed, rating, tier,
/// personality. In v2 an online player maps onto this same shape.
class BotProfile {
  final String id;
  final String name;
  final String countryIso;
  final String countryName;
  final String avatarSeed;
  final int rating;
  final BotTier tier;
  final BotPersonality personality;
  final String title;

  const BotProfile({
    required this.id,
    required this.name,
    required this.countryIso,
    required this.countryName,
    required this.avatarSeed,
    required this.rating,
    required this.tier,
    required this.personality,
    required this.title,
  });

  String get displayName => title.isEmpty ? name : '$title $name';
}
