import 'dart:math';

/// Deterministic ELO preview (shown before the game, no jitter).
class EloPreview {
  final int win;
  final int draw;
  final int loss;

  const EloPreview({required this.win, required this.draw, required this.loss});
}

/// Standard ELO with dynamic K-factor. New players (games < 30) move fast;
/// established ratings move slowly. A tiny +/-1 jitter on the final delta
/// keeps results feeling alive (+5, +6, +8 ...).
class EloService {
  EloService._();

  static int kFactor({required int rating, required int gamesPlayed}) {
    if (gamesPlayed < 30) return 40;
    if (rating < 1500) return 32;
    if (rating < 2000) return 24;
    return 16;
  }

  static double expectedScore(double player, double opponent) {
    return 1.0 / (1.0 + pow(10.0, (opponent - player) / 400.0));
  }

  static int _baseDelta({
    required int playerRating,
    required int botRating,
    required int gamesPlayed,
    required double score,
  }) {
    final k = kFactor(rating: playerRating, gamesPlayed: gamesPlayed);
    final exp = expectedScore(playerRating.toDouble(), botRating.toDouble());
    return (k * (score - exp)).round();
  }

  static EloPreview preview({
    required int playerRating,
    required int botRating,
    required int gamesPlayed,
  }) {
    var win = _baseDelta(
      playerRating: playerRating,
      botRating: botRating,
      gamesPlayed: gamesPlayed,
      score: 1.0,
    );
    final draw = _baseDelta(
      playerRating: playerRating,
      botRating: botRating,
      gamesPlayed: gamesPlayed,
      score: 0.5,
    );
    var loss = _baseDelta(
      playerRating: playerRating,
      botRating: botRating,
      gamesPlayed: gamesPlayed,
      score: 0.0,
    );
    if (win < 3) win = 3;
    if (loss > -3) loss = -3;
    return EloPreview(win: win, draw: draw, loss: loss);
  }

  static int finalDelta({
    required int playerRating,
    required int botRating,
    required int gamesPlayed,
    required double score,
    Random? random,
  }) {
    var d = _baseDelta(
      playerRating: playerRating,
      botRating: botRating,
      gamesPlayed: gamesPlayed,
      score: score,
    );
    final r = random ?? Random();
    d += r.nextInt(3) - 1; // -1, 0 or +1
    if (score >= 1.0 && d < 3) d = 3;
    if (score <= 0.0 && d > -3) d = -3;
    return d;
  }

  static String formatDelta(int d) => d >= 0 ? '+$d' : '$d';
}
