import 'dart:math';

import 'package:country_pickers/country.dart';
import 'package:country_pickers/utils/utils.dart';

import '../domain/bot_difficulty.dart';
import '../domain/bot_personality.dart';
import '../domain/bot_profile.dart';
import 'bot_names.dart';

/// Generates a fair, varied CPU opponent.
///
/// * 60% near the player's rating (+/-150), 25% weaker, 15% stronger.
/// * Rubber-banding: win streaks pull stronger bots, losing streaks pull
///   kinder ones, so the game stays fun without feeling rigged.
/// * Rating is clamped to 400..2400.
class BotGenerator {
  BotGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  int _jitter(int span) => _random.nextInt(span * 2 + 1) - span;

  BotProfile generate({
    required int playerRating,
    required int winStreak,
    required int lossStreak,
  }) {
    final roll = _random.nextDouble();
    var botRating = playerRating;
    if (roll < 0.60) {
      botRating = playerRating + _jitter(150);
    } else if (roll < 0.85) {
      botRating = playerRating - 150 - _random.nextInt(250);
    } else {
      botRating = playerRating + 150 + _random.nextInt(200);
    }
    if (winStreak >= 3) botRating += 120;
    if (lossStreak >= 3) botRating -= 120;
    if (botRating < 400) botRating = 400;
    if (botRating > 2400) botRating = 2400;

    var iso = BotNamePool
        .weightedIsos[_random.nextInt(BotNamePool.weightedIsos.length)];
    Country country;
    try {
      country = CountryPickerUtils.getCountryByIsoCode(iso);
    } catch (_) {
      iso = 'US';
      country = CountryPickerUtils.getCountryByIsoCode('US');
    }

    final name = _makeName(iso);
    final personalities = BotPersonality.values;
    final personality =
        personalities[_random.nextInt(personalities.length)];

    return BotProfile(
      id: 'bot-${_random.nextInt(1 << 31)}',
      name: name,
      countryIso: iso,
      countryName: country.name,
      avatarSeed: '$name-${_random.nextInt(1 << 30)}',
      rating: botRating,
      tier: BotTiering.tierForRating(botRating),
      personality: personality,
      title: BotTiering.titleForRating(botRating),
    );
  }

  String _makeName(String iso) {
    var base = '';
    if (_random.nextDouble() >= 0.45) {
      final pool = BotNamePool.firstNamesByIso[iso];
      if (pool != null && pool.isNotEmpty) {
        base = pool[_random.nextInt(pool.length)];
      }
    }
    if (base.isEmpty) {
      base =
          BotNamePool.handles[_random.nextInt(BotNamePool.handles.length)]
              .trim();
    }
    final style = _random.nextDouble();
    if (style < 0.55) return '$base${10 + _random.nextInt(90)}';
    if (style < 0.70) return '$base${100 + _random.nextInt(900)}';
    if (style < 0.80) return '_$base';
    return base;
  }
}
