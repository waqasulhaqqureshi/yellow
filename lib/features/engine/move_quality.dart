/// Verdicts for a single move, from the mover's perspective.
enum MoveVerdict { book, brilliant, good, inaccuracy, mistake, blunder }

extension MoveVerdictX on MoveVerdict {
  String get label {
    switch (this) {
      case MoveVerdict.book:
        return 'Book';
      case MoveVerdict.brilliant:
        return 'Brilliant';
      case MoveVerdict.good:
        return 'Good';
      case MoveVerdict.inaccuracy:
        return 'Inaccuracy';
      case MoveVerdict.mistake:
        return 'Mistake';
      case MoveVerdict.blunder:
        return 'Blunder';
    }
  }

  /// Standard chess annotation.
  String get glyph {
    switch (this) {
      case MoveVerdict.book:
        return '';
      case MoveVerdict.brilliant:
        return '!!';
      case MoveVerdict.good:
        return '';
      case MoveVerdict.inaccuracy:
        return '?!';
      case MoveVerdict.mistake:
        return '?';
      case MoveVerdict.blunder:
        return '??';
    }
  }
}

class MoveAssessment {
  final MoveVerdict verdict;

  /// Centipawns lost by the mover (clamped at 0; gains read as 0).
  final int swingCp;
  final bool gaveCheck;
  final bool wasCapture;
  final int capturedValue;

  const MoveAssessment({
    required this.verdict,
    required this.swingCp,
    this.gaveCheck = false,
    this.wasCapture = false,
    this.capturedValue = 0,
  });
}

/// Classifies moves by evaluation swing and keeps per-game blunder counts.
/// Feeds chat reactions, post-game stats and the bot's mercy adjustment.
class BlunderTracker {
  int userMoves = 0;
  int botMoves = 0;
  int userBlunders = 0;
  int userMistakes = 0;
  int userInaccuracies = 0;
  int userBrilliant = 0;
  int botBlunders = 0;
  int botMistakes = 0;
  int botInaccuracies = 0;
  int botBrilliant = 0;
  int userChecks = 0;
  int botChecks = 0;
  int _userCentipawnLoss = 0;
  int _botCentipawnLoss = 0;

  int? get userAccuracy => _accuracy(userMoves, _userCentipawnLoss);
  int? get botAccuracy => _accuracy(botMoves, _botCentipawnLoss);

  int? _accuracy(int moves, int centipawnLoss) {
    if (moves == 0) return null;
    final averageLoss = centipawnLoss / moves;
    return (100 - (averageLoss / 10).round()).clamp(0, 100).toInt();
  }

  void reset() {
    userMoves = 0;
    botMoves = 0;
    userBlunders = 0;
    userMistakes = 0;
    userInaccuracies = 0;
    userBrilliant = 0;
    botBlunders = 0;
    botMistakes = 0;
    botInaccuracies = 0;
    botBrilliant = 0;
    userChecks = 0;
    botChecks = 0;
    _userCentipawnLoss = 0;
    _botCentipawnLoss = 0;
  }

  MoveAssessment assess({
    required int evalBeforeMoverCp,
    required int evalAfterMoverCp,
    required bool isBookMove,
    bool gaveCheck = false,
    bool wasCapture = false,
    int capturedValue = 0,
  }) {
    final swing = evalBeforeMoverCp - evalAfterMoverCp;
    MoveVerdict verdict;
    if (isBookMove) {
      verdict = MoveVerdict.book;
    } else if (swing >= 250) {
      verdict = MoveVerdict.blunder;
    } else if (swing >= 130) {
      verdict = MoveVerdict.mistake;
    } else if (swing >= 70) {
      verdict = MoveVerdict.inaccuracy;
    } else if (swing <= -180) {
      verdict = MoveVerdict.brilliant;
    } else {
      verdict = MoveVerdict.good;
    }
    return MoveAssessment(
      verdict: verdict,
      swingCp: swing < 0 ? 0 : swing,
      gaveCheck: gaveCheck,
      wasCapture: wasCapture,
      capturedValue: capturedValue,
    );
  }

  void recordHuman(MoveAssessment a) {
    userMoves++;
    _userCentipawnLoss += a.swingCp;
    if (a.gaveCheck) userChecks++;
    switch (a.verdict) {
      case MoveVerdict.blunder:
        userBlunders++;
        break;
      case MoveVerdict.mistake:
        userMistakes++;
        break;
      case MoveVerdict.inaccuracy:
        userInaccuracies++;
        break;
      case MoveVerdict.brilliant:
        userBrilliant++;
        break;
      default:
        break;
    }
  }

  void recordBot(MoveAssessment a) {
    botMoves++;
    _botCentipawnLoss += a.swingCp;
    if (a.gaveCheck) botChecks++;
    switch (a.verdict) {
      case MoveVerdict.blunder:
        botBlunders++;
        break;
      case MoveVerdict.mistake:
        botMistakes++;
        break;
      case MoveVerdict.inaccuracy:
        botInaccuracies++;
        break;
      case MoveVerdict.brilliant:
        botBrilliant++;
        break;
      default:
        break;
    }
  }
}
