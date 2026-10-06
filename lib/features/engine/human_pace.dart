import 'dart:math';

/// Human-like move pacing derived from real online-chess timing data.
///
/// Real players do not move in under a second like a raw engine. Published
/// community statistics put the average time per move at roughly:
///   • bullet  ~2 s   [lichess forum move-rate estimates]
///   • blitz   ~5 s   [lichess forum move-rate estimates]
///   • rapid   ~10 s  [lichess estimates; chess.com players report 11–14 s]
///
/// Crucially, human move times are NOT uniform: most moves are quick-ish
/// with a long tail of real thinks, and weaker players are *slower and more
/// erratic* (they hesitate on obvious moves, snap on complex ones), not
/// faster. [HumanPace.sampleThinkMs] draws from an exponential-ish spread so
/// every move feels different, exactly like a real person.
class HumanPace {
  HumanPace._();

  /// Baseline average seconds a human spends per move at this time control.
  static double baseSecondsPerMove(String timeControl) => switch (timeControl) {
        'Bullet' => 1.6,
        'Turbo' => 2.4,
        'Tempo' => 3.0,
        'Chill' => 4.0,
        'Rapid' => 9.0,
        _ => 4.5, // Blitz and anything unknown.
      };

  /// Rating factor. Weak players are indecisive and slow on average; they
  /// burn time on obvious moves and then snap out a blunder. Strong players
  /// are efficient on routine moves and save long thinks for key moments.
  static double ratingFactor(int rating) {
    if (rating < 850) return 1.3;
    if (rating < 1200) return 1.1;
    if (rating < 1600) return 1.0;
    if (rating < 2000) return 0.95;
    return 1.0;
  }

  /// Draws ONE human-like think time in milliseconds.
  ///
  /// [trait] is a per-game player tempo (some humans are simply faster or
  /// slower players); pass the brain's stable per-game value.
  ///
  /// [humanAvgSec] is the live EMA of the opponent's own seconds per move.
  /// When known, the bot converges to *the user's* speed (75% user pace,
  /// 25% model pace) — a fast player gets a fast opponent, a thinker gets
  /// a thinker, exactly like being paired with a human of your habits.
  ///
  /// The distribution is exponential-ish: many quick moves, a healthy spread
  /// of longer thinks, and rare pauses — never a metronome.
  static int sampleThinkMs({
    required String timeControl,
    required int rating,
    required Random random,
    double trait = 1.0,
    double? humanAvgSec,
  }) {
    final modelMs = baseSecondsPerMove(timeControl) *
        ratingFactor(rating) *
        trait *
        1000;
    final avgMs = humanAvgSec == null
        ? modelMs.round()
        : ((humanAvgSec.clamp(1.0, 60.0) * 1000) * 0.75 + modelMs * 0.25)
            .round();

    // Exponential sample in ~[0, 3.9), mean ≈ 1: short moves common,
    // long thinks form a natural tail.
    final u = random.nextDouble();
    final expSample = -log(1 - u * 0.98);
    var ms = avgMs * (0.35 + 0.75 * expSample);

    // Weak players occasionally freeze, unsure what to do at all.
    if (rating < 1000 && random.nextDouble() < 0.06) {
      ms += 5000 + random.nextInt(7000);
    }
    // Anyone can have a genuine think when the position gets sharp.
    if (random.nextDouble() < 0.05) {
      ms += 3000 + random.nextInt(5000);
    }

    if (ms < 600) ms = 600;
    if (ms > 25000) ms = 25000;
    return ms.round();
  }

  /// A (min, max) window kept for tooling / debug screens that want a range
  /// instead of a sample.
  static (int, int) thinkWindowMs({
    required String timeControl,
    required int rating,
  }) {
    final avgMs =
        (baseSecondsPerMove(timeControl) * ratingFactor(rating) * 1000).round();
    var min = (avgMs * 0.4).round();
    var max = (avgMs * 3.0).round();
    if (min < 600) min = 600;
    if (max < min + 800) max = min + 800;
    return (min, max);
  }
}
