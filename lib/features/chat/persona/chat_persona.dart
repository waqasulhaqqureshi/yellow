import 'dart:math';

import '../../bot/domain/bot_profile.dart';
import 'geo_data.dart';

/// The social "voice" of a bot. Mirrors how real online players differ:
/// some open friendly, some salty, some barely type at all.
enum ChatStyle {
  /// Warm, polite, complimentary.
  friendly,

  /// Opens with mild trash-talk / bravado (never slurs — Play-Store safe).
  salty,

  /// Impatient, curt, one-word-ish, wants to move fast.
  rash,

  /// Balanced baseline.
  normal,

  /// Rarely replies; often leaves you on read.
  silent,

  /// Emoji-heavy, upbeat.
  cheerful,

  /// Proper punctuation, no slang, almost formal.
  formal,
}

extension ChatStyleX on ChatStyle {
  String get label {
    switch (this) {
      case ChatStyle.friendly:
        return 'Friendly';
      case ChatStyle.salty:
        return 'Salty';
      case ChatStyle.rash:
        return 'Rash';
      case ChatStyle.normal:
        return 'Normal';
      case ChatStyle.silent:
        return 'Quiet';
      case ChatStyle.cheerful:
        return 'Cheerful';
      case ChatStyle.formal:
        return 'Formal';
    }
  }
}

/// Everything that makes one bot's chat feel like one specific person.
/// Generated once per [BotProfile] (seeded) so it stays consistent across the
/// whole game and across rematches with the same seed.
class ChatPersona {
  const ChatPersona({
    required this.style,
    required this.city,
    required this.country,
    required this.responseRate,
    required this.typoRate,
    required this.slangRate,
    required this.emojiRate,
    required this.asksQuestions,
    required this.introEagerness,
  });

  final ChatStyle style;
  final String city;
  final String country;

  /// Chance (0..1) the bot replies to a user message at all.
  final double responseRate;

  /// Chance a word gets a human typo.
  final double typoRate;

  /// Chance to swap in slang / contractions ("u", "ur", "gonna").
  final double slangRate;

  /// Chance to sprinkle emoji.
  final double emojiRate;

  /// Whether the bot asks you follow-up questions.
  final bool asksQuestions;

  /// How eagerly the bot introduces itself at game start.
  final double introEagerness;

  bool get usesTypos => typoRate > 0;

  /// Builds a consistent persona for [bot], seeded by its id so the same bot
  /// always chats the same way.
  static ChatPersona fromBot(BotProfile bot, {Random? random}) {
    final seed = bot.id.hashCode ^ bot.avatarSeed.hashCode;
    final rng = Random(seed);

    final style = _pickStyle(rng);

    double responseRate;
    double typoRate;
    double slangRate;
    double emojiRate;
    bool asksQuestions;
    double introEagerness;

    switch (style) {
      case ChatStyle.silent:
        responseRate = 0.25;
        typoRate = 0.10;
        slangRate = 0.20;
        emojiRate = 0.02;
        asksQuestions = false;
        introEagerness = 0.2;
        break;
      case ChatStyle.formal:
        responseRate = 0.9;
        typoRate = 0.0;
        slangRate = 0.02;
        emojiRate = 0.03;
        asksQuestions = true;
        introEagerness = 0.8;
        break;
      case ChatStyle.rash:
        responseRate = 0.6;
        typoRate = 0.22;
        slangRate = 0.45;
        emojiRate = 0.05;
        asksQuestions = false;
        introEagerness = 0.4;
        break;
      case ChatStyle.salty:
        responseRate = 0.75;
        typoRate = 0.14;
        slangRate = 0.40;
        emojiRate = 0.08;
        asksQuestions = false;
        introEagerness = 0.7;
        break;
      case ChatStyle.cheerful:
        responseRate = 0.9;
        typoRate = 0.08;
        slangRate = 0.30;
        emojiRate = 0.5;
        asksQuestions = true;
        introEagerness = 0.9;
        break;
      case ChatStyle.friendly:
        responseRate = 0.9;
        typoRate = 0.10;
        slangRate = 0.25;
        emojiRate = 0.15;
        asksQuestions = true;
        introEagerness = 0.9;
        break;
      case ChatStyle.normal:
        responseRate = 0.8;
        typoRate = 0.12;
        slangRate = 0.28;
        emojiRate = 0.10;
        asksQuestions = rng.nextBool();
        introEagerness = 0.6;
        break;
    }

    return ChatPersona(
      style: style,
      city: GeoData.cityFor(bot.countryIso, rng),
      country: GeoData.countryFor(bot.countryIso),
      responseRate: responseRate,
      typoRate: typoRate,
      slangRate: slangRate,
      emojiRate: emojiRate,
      asksQuestions: asksQuestions,
      introEagerness: introEagerness,
    );
  }

  static ChatStyle _pickStyle(Random rng) {
    final roll = rng.nextDouble();
    if (roll < 0.30) return ChatStyle.normal;
    if (roll < 0.48) return ChatStyle.friendly;
    if (roll < 0.60) return ChatStyle.salty;
    if (roll < 0.72) return ChatStyle.rash;
    if (roll < 0.82) return ChatStyle.cheerful;
    if (roll < 0.90) return ChatStyle.formal;
    return ChatStyle.silent;
  }
}
