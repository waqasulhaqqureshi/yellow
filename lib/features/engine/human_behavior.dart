import 'dart:math';

import '../bot/domain/bot_personality.dart';
import 'move_quality.dart';

/// A single named, human-like behavior the bot can exhibit this move.
/// Returned so the UI / chat can react to and narrate it.
class BehaviorNote {
  final HumanBehavior id;
  final String label;

  const BehaviorNote(this.id, this.label);
}

/// The catalog of human-like behaviors the arena bot can display.
/// Each maps to concrete logic in [HumanBehaviorEngine]. Kept as an enum so
/// the game-over summary and debug tooling can enumerate exactly which
/// behaviors fired in a given game.
enum HumanBehavior {
  openingConfidence,
  recaptureInstinct,
  exploitPause,
  surprisePause,
  timeTroublePanic,
  fatigue,
  tiltAfterBlunder,
  mercy,
  resignation,
  drawOffer,
  endgameInaccuracy,
  afkPause,
  clockManagement,
  checkReaction,
  momentumAggression,
  politeness,
  hesitation,
  noShuffle,
  flagHunter,
}

/// Inputs describing the current game state for one bot decision.
class BehaviorInput {
  final int moveCount; // plies played
  final int botClockSec;
  final int humanClockSec;
  final int evalWhiteCp; // White (human) perspective
  final MoveVerdict? lastHumanVerdict;
  final bool humanJustCaptured;
  final bool botJustCaptured;
  final bool humanInCheck; // bot just gave check
  final bool botInCheck; // bot must answer check now
  final int searchSpreadCp; // gap between best and 2nd best candidate
  final bool isEndgame;

  const BehaviorInput({
    required this.moveCount,
    required this.botClockSec,
    required this.humanClockSec,
    required this.evalWhiteCp,
    this.lastHumanVerdict,
    this.humanJustCaptured = false,
    this.botJustCaptured = false,
    this.humanInCheck = false,
    this.botInCheck = false,
    this.searchSpreadCp = 0,
    this.isEndgame = false,
  });
}

/// Everything the engine decided for the upcoming bot move.
class BotMovePlan {
  /// Added think time in ms (can be negative to speed up).
  final int thinkDeltaMs;

  /// Multiplier applied to the base deliberate-blunder rate (>= 0).
  final double blunderMultiplier;

  /// Extra depth reduction for low tiers in the endgame (0 = none).
  final int depthPenalty;

  final List<BehaviorNote> notes;

  const BotMovePlan({
    this.thinkDeltaMs = 0,
    this.blunderMultiplier = 1.0,
    this.depthPenalty = 0,
    this.notes = const [],
  });
}

/// Decides HOW a human would play this move, layered on top of the raw
/// engine strength. Pure logic — no Flutter widgets — so it is testable.
class HumanBehaviorEngine {
  HumanBehaviorEngine({
    required this.personality,
    required this.random,
  });

  final BotPersonality personality;
  final Random random;

  // Running emotional state, -3..+3 style counters.
  int _botTilt = 0; // rises when the bot blunders.
  int _botConfidence = 0; // rises when the human blunders.
  int _behaviorsFired = 0;
  final Map<HumanBehavior, int> _firedCounts = {};

  int get behaviorsFired => _behaviorsFired;

  Map<HumanBehavior, int> get firedCounts => Map.unmodifiable(_firedCounts);

  void reset() {
    _botTilt = 0;
    _botConfidence = 0;
    _behaviorsFired = 0;
    _firedCounts.clear();
  }

  void _note(HumanBehavior id, String label, List<BehaviorNote> sink) {
    sink.add(BehaviorNote(id, label));
    _firedCounts[id] = (_firedCounts[id] ?? 0) + 1;
    _behaviorsFired++;
  }

  /// Called after the human's move is applied, before the bot replies.
  void observeHuman(MoveAssessment assessment) {
    switch (assessment.verdict) {
      case MoveVerdict.blunder:
        _botConfidence = (_botConfidence + 1).clamp(0, 3);
        break;
      case MoveVerdict.brilliant:
        _botConfidence = (_botConfidence - 1).clamp(0, 3);
        break;
      default:
        break;
    }
  }

  /// Called after the bot's own move is assessed (its own mistakes tilt it).
  void observeBot(MoveAssessment assessment) {
    if (assessment.verdict == MoveVerdict.blunder) {
      _botTilt = (_botTilt + 1).clamp(0, 3);
    } else if (assessment.verdict == MoveVerdict.good ||
        assessment.verdict == MoveVerdict.brilliant) {
      _botTilt = (_botTilt - 1).clamp(0, 3);
    }
  }

  /// Builds the think-time / error plan for the next bot move.
  BotMovePlan plan(BotMoveInput input) {
    final notes = <BehaviorNote>[];
    var delta = 0;
    var mult = 1.0;
    var depthPenalty = 0;
    final i = input.state;

    // 1. Opening confidence: humans blast out theory.
    if (i.moveCount < 8) {
      delta -= 350 + random.nextInt(250);
      _note(HumanBehavior.openingConfidence, 'instant book-style move', notes);
    }

    // 2. Recapture instinct: an obvious recapture is nearly instant.
    if (i.humanJustCaptured && i.searchSpreadCp > 120) {
      delta -= 300 + random.nextInt(200);
      _note(HumanBehavior.recaptureInstinct, 'fast recapture', notes);
    }

    // 3. Exploit pause: after a human blunder, a human double-checks.
    if (i.lastHumanVerdict == MoveVerdict.blunder) {
      delta += 500 + random.nextInt(600);
      _note(HumanBehavior.exploitPause, 'verifying your blunder', notes);
    }

    // 4. Surprise pause after a brilliant move.
    if (i.lastHumanVerdict == MoveVerdict.brilliant) {
      delta += 400 + random.nextInt(500);
      _note(HumanBehavior.surprisePause, 'surprised by your move', notes);
    }

    // 5. Time-trouble panic: low clock => faster, sloppier.
    if (i.botClockSec < 30) {
      delta -= 400 + random.nextInt(300);
      mult += 0.5;
      _note(HumanBehavior.timeTroublePanic, 'low clock, rushing', notes);
    }

    // 6. Fatigue: long games raise error rate slightly.
    if (i.moveCount > 60) {
      mult += 0.25;
      _note(HumanBehavior.fatigue, 'tired in a long game', notes);
    }

    // 7. Tilt after own blunder: shaky next move.
    if (_botTilt >= 1) {
      mult += 0.25 * _botTilt;
      _note(HumanBehavior.tiltAfterBlunder, 'still tilted', notes);
    }

    // 8. Mercy: ease off a crushing advantage so the human can fight back.
    if (i.evalWhiteCp < -600) {
      mult += 0.2;
      _note(HumanBehavior.mercy, 'easing off a won game', notes);
    }

    // 11. Endgame inaccuracy for weaker personalities.
    if (i.isEndgame && _isWeakPersonality) {
      depthPenalty = 1;
      mult += 0.2;
      _note(HumanBehavior.endgameInaccuracy, 'sloppy technique', notes);
    }

    // 12. Rare AFK pause: the human looked away from the screen.
    if (random.nextDouble() < 0.015) {
      delta += 2500 + random.nextInt(3000);
      _note(HumanBehavior.afkPause, 'stepped away briefly', notes);
    }

    // 13. Clock management: play quicker when comfortably winning.
    if (i.evalWhiteCp < -300 && i.botClockSec > i.humanClockSec) {
      delta -= 150 + random.nextInt(150);
      _note(HumanBehavior.clockManagement, 'confident, speeding up', notes);
    }

    // 14. Check reaction: answering check is instinctive.
    if (i.botInCheck) {
      delta -= 200 + random.nextInt(150);
      _note(HumanBehavior.checkReaction, 'instinctive check reply', notes);
    }

    // 17. Hesitation: close candidates cause real indecision.
    if (i.searchSpreadCp > 0 && i.searchSpreadCp < 40 && i.moveCount > 10) {
      delta += 350 + random.nextInt(400);
      _note(HumanBehavior.hesitation, 'torn between two moves', notes);
    }

    // 18. Flag hunter: a human opponent keeps moving fast to pile the
    // pressure on when YOUR clock is about to die.
    if (i.humanClockSec < 20 && i.botClockSec > 30) {
      delta -= 500 + random.nextInt(400);
      _note(HumanBehavior.flagHunter, 'speeding up to flag you', notes);
    }

    return BotMovePlan(
      thinkDeltaMs: delta,
      blunderMultiplier: mult,
      depthPenalty: depthPenalty,
      notes: notes,
    );
  }

  bool get _isWeakPersonality =>
      personality == BotPersonality.aggressive ||
      personality == BotPersonality.trickster;

  /// Should the bot resign right now? Personality-aware thresholds.
  bool shouldResign(BotMoveInput input) {
    final evalBlack = -input.state.evalWhiteCp;
    // Only resign when genuinely lost and the game is not brand new.
    if (input.state.moveCount < 20) return false;
    int threshold;
    switch (personality) {
      case BotPersonality.aggressive:
        threshold = -900; // fights to the end.
        break;
      case BotPersonality.calm:
        threshold = -700;
        break;
      case BotPersonality.showman:
        threshold = -1100; // never gives the crowd an early exit.
        break;
      default:
        threshold = -800;
    }
    if (evalBlack < threshold && random.nextDouble() < 0.25) {
      return true;
    }
    return false;
  }

  /// Should the bot offer a draw?
  bool shouldOfferDraw(BotMoveInput input) {
    final evalBlack = -input.state.evalWhiteCp;
    // A human offers draws when slightly worse or dead equal and tired.
    final tired = input.state.moveCount > 50;
    if (evalBlack > -100 && evalBlack < 100 && tired &&
        random.nextDouble() < 0.10) {
      return true;
    }
    if (evalBlack < -200 && evalBlack > -400 && random.nextDouble() < 0.08) {
      return true;
    }
    return false;
  }
}

/// Bundles the behavior engine with the live state it needs for one call.
class BotMoveInput {
  final BehaviorInput state;

  const BotMoveInput({required this.state});
}
