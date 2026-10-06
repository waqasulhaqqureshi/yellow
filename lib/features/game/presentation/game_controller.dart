import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:genetom_chess_engine/genetom_chess_engine.dart';

import '../../../core/utils/piece_glyphs.dart';
import '../../bot/domain/bot_profile.dart';
import '../../chat/bot_chat_brain.dart';
import '../../chat/chat_matrix.dart';
import '../../engine/arena_brain.dart';
import '../../engine/chess_eval.dart';
import '../../engine/difficulty_mapper.dart';
import '../../engine/human_behavior.dart';
import '../../engine/move_quality.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/game_record.dart';
import '../../rating/match_point_system.dart';
import '../domain/game_result.dart';
import 'move_record.dart';

enum PlayPhase { loading, playing, gameOver }

class CapturedInfo {
  /// Black piece values captured by the human.
  final List<int> byHuman;

  /// White piece values captured by the bot.
  final List<int> byBot;
  final int materialWhiteCp;

  const CapturedInfo({
    this.byHuman = const [],
    this.byBot = const [],
    this.materialWhiteCp = 0,
  });
}

/// Owns one game: board state, turn flow, promotion, draw/resign, ELO
/// settlement and chat wiring. One instance per GameScreen.
class GameController extends ChangeNotifier {
  GameController({
    required this.bot,
    required this.profileRepo,
    this.timeControl = 'Blitz',
    Random? random,
  }) : _random = random ?? Random();

  final BotProfile bot;
  final ProfileRepository profileRepo;
  final String timeControl;

  /// Exponential moving average of the human's seconds per move. The bot
  /// mirrors this so it plays at roughly the user's own speed.
  DateTime? _lastHumanMoveAt;
  double? _humanPaceSec;
  double? get humanPaceSec => _humanPaceSec;
  final Random _random;
  late final MatchDifficulty matchDifficulty = MatchPointSystem.difficultyFor(
    playerRating: profileRepo.profile.rating,
    botRating: bot.rating,
  );

  late final ArenaBrain brain;
  late final BotChatBrain chat;

  PlayPhase _phase = PlayPhase.loading;
  PlayPhase get phase => _phase;

  List<List<int>> _board = List.generate(8, (_) => List<int>.filled(8, 0));
  List<List<int>> get board => _board;

  bool _humanTurn = true;
  bool get humanTurn => _humanTurn;

  bool _botThinking = false;
  bool get botThinking => _botThinking;

  CellPosition? _selected;
  CellPosition? get selected => _selected;

  List<CellPosition> _validTargets = const [];
  List<CellPosition> get validTargets => _validTargets;

  MovesModel? _lastMove;
  MovesModel? get lastMove => _lastMove;

  final List<MoveRecord> _moves = [];
  List<MoveRecord> get moves => List.unmodifiable(_moves);

  CapturedInfo _captured = const CapturedInfo();
  CapturedInfo get captured => _captured;

  bool _humanInCheck = false;
  bool get humanInCheck => _humanInCheck;

  bool _botInCheck = false;
  bool get botInCheck => _botInCheck;

  /// Promotion dialog state (human = White).
  bool _promotionOpen = false;
  bool get promotionOpen => _promotionOpen;

  CellPosition? _promotionPos;
  CellPosition? get promotionPos => _promotionPos;

  GameResult? _playerResult;
  GameResult? get playerResult => _playerResult;

  String _resultTitle = '';
  String get resultTitle => _resultTitle;

  String _resultSubtitle = '';
  String get resultSubtitle => _resultSubtitle;

  int? _eloDelta;
  int? get eloDelta => _eloDelta;

  int? _newRating;
  int? get newRating => _newRating;

  bool _isStalemate = false;
  bool get isStalemate => _isStalemate;

  /// Live clocks (seconds), fed by the screen, so the behavior engine can
  /// simulate time-trouble panic and clock management.
  int humanClockSec = 999;
  int botClockSec = 999;

  void updateClocks({required int human, required int bot}) {
    humanClockSec = human;
    botClockSec = bot;
  }

  /// Non-null while the bot has an outstanding draw offer on the table.
  bool _botDrawOfferPending = false;
  bool get botDrawOfferPending => _botDrawOfferPending;

  int get fullMoves => (_moves.length + 1) ~/ 2;

  Timer? _idleTimer;
  bool _disposed = false;

  Future<void> init() async {
    final settings = DifficultyMapper.forMatch(
      playerRating: profileRepo.profile.rating,
      botRating: bot.rating,
      timeControl: timeControl,
    );
    brain = ArenaBrain(
      settings: settings,
      personality: bot.personality,
      random: _random,
    );
    chat = BotChatBrain(
      bot: bot,
      humanName: profileRepo.profile.name,
      random: _random,
    );

    brain.onBoardChanged = (b) {
      if (_disposed) return;
      _board = b;
      _refreshDerived();
      notifyListeners();
    };
    brain.onGameOver = (g) => _onEngineGameOver(g);
    brain.onPromotionNeeded = (isWhite, pos) {
      if (_disposed) return;
      if (!isWhite || _phase != PlayPhase.playing) {
        // Bot (Black) always queens — instant, no dialog. Same for any
        // promotion arriving after the game already ended (e.g. mate with
        // promotion: the callback lands ~100ms after game-over).
        brain.setPromotion(pos, ChessPiece.queen);
      } else {
        _promotionPos = pos;
        _promotionOpen = true;
        notifyListeners();
      }
    };

    brain.init();
    _board = ChessEval.copyBoard(brain.board);
    _refreshDerived();
    _phase = PlayPhase.playing;
    notifyListeners();

    // Persona-driven opener (greeting + maybe "where are you from?").
    await chat.startIntro();
    _armIdleNudge();
  }

  void _refreshDerived() {
    _humanInCheck = ChessEval.isInCheck(_board, true);
    _botInCheck = ChessEval.isInCheck(_board, false);
    _captured = _computeCaptured(_board);
  }

  CapturedInfo _computeCaptured(List<List<int>> b) {
    const need = {
      pawnPower: 8,
      horsePower: 2,
      bishopPower: 2,
      rookPower: 2,
      queenPower: 1,
    };
    final whiteHave = {for (final k in need.keys) k: 0};
    final blackHave = {for (final k in need.keys) k: 0};
    for (final row in b) {
      for (final v in row) {
        if (v == 0 || v.abs() == kingPower) continue;
        if (v > 0) {
          whiteHave[v.abs()] = (whiteHave[v.abs()] ?? 0) + 1;
        } else {
          blackHave[v.abs()] = (blackHave[v.abs()] ?? 0) + 1;
        }
      }
    }
    // Promotions can push counts above the initial ones — clamp at zero.
    final byHuman = <int>[];
    final byBot = <int>[];
    need.forEach((power, count) {
      var missingBlack = count - (blackHave[power] ?? 0);
      while (missingBlack > 0) {
        byHuman.add(-power);
        missingBlack--;
      }
      var missingWhite = count - (whiteHave[power] ?? 0);
      while (missingWhite > 0) {
        byBot.add(power);
        missingWhite--;
      }
    });
    byHuman.sort((a, b) => b.abs().compareTo(a.abs()));
    byBot.sort((a, b) => b.abs().compareTo(a.abs()));
    return CapturedInfo(
      byHuman: byHuman,
      byBot: byBot,
      materialWhiteCp: ChessEval.materialWhiteCp(b),
    );
  }

  void onSquareTap(int row, int col) {
    if (_phase != PlayPhase.playing || !_humanTurn || _botThinking) return;
    if (_promotionOpen) return;

    // Tap on a valid target -> move.
    if (_selected != null) {
      for (final t in _validTargets) {
        if (t.row == row && t.col == col) {
          _playHumanMove(_selected!, t);
          return;
        }
      }
    }

    // Tap own piece -> select.
    final v = _board[row][col];
    if (v > 0) {
      if (_selected != null &&
          _selected!.row == row &&
          _selected!.col == col) {
        _selected = null;
        _validTargets = const [];
      } else {
        _selected = CellPosition(row: row, col: col);
        _validTargets = brain.validMovesFor(_selected!);
        if (_validTargets.isEmpty) _selected = null;
      }
      notifyListeners();
      return;
    }

    // Tap elsewhere -> deselect.
    if (_selected != null) {
      _selected = null;
      _validTargets = const [];
      notifyListeners();
    }
  }

  Future<void> _playHumanMove(CellPosition from, CellPosition to) async {
    // Track the human's move cadence and feed it to the brain so the bot
    // settles at roughly the player's own speed.
    final now = DateTime.now();
    final prev = _lastHumanMoveAt;
    _lastHumanMoveAt = now;
    if (prev != null) {
      final e = now.difference(prev).inMilliseconds / 1000.0;
      if (e > 0.5 && e < 90) {
        _humanPaceSec =
            _humanPaceSec == null ? e : _humanPaceSec! * 0.7 + e * 0.3;
        brain.humanPaceSec = _humanPaceSec;
      }
    }
    final move = MovesModel(
      currentPosition: CellPosition(row: from.row, col: from.col),
      targetPosition: CellPosition(row: to.row, col: to.col),
    );
    final label = PieceGlyphs.prettyMove(move, _board);
    final movingPiece = _board[from.row][from.col];
    final glyph = PieceGlyphs.glyphFor(movingPiece);
    _selected = null;
    _validTargets = const [];
    _humanTurn = false;
    _botThinking = true;
    _cancelIdle();
    // Moving on without accepting reads as a polite decline of any pending
    // bot draw offer.
    if (_botDrawOfferPending) _botDrawOfferPending = false;
    notifyListeners();

    HumanMoveOutcome outcome;
    try {
      outcome = brain.playHumanMove(move);
    } catch (_) {
      _humanTurn = true;
      _botThinking = false;
      notifyListeners();
      return;
    }
    _lastMove = move;
    _moves.add(
      MoveRecord(
        move: move,
        uci: PieceGlyphs.uciFor(move),
        label: label,
        glyph: glyph,
        byHuman: true,
        verdict: outcome.assessment.verdict,
      ),
    );
    notifyListeners();

    brain.behavior.observeHuman(outcome.assessment);
    _reactToHumanMove(outcome);
    if (_phase != PlayPhase.playing) return; // mating move etc.

    // Pawn promotion resolves via a delayed engine callback (~100ms): give
    // it a grace window, then wait for the player's choice so the bot never
    // replies (or captures!) before the new piece exists.
    if (movingPiece == pawnPower && to.row == 0) {
      await Future.delayed(const Duration(milliseconds: 350));
      var guard = 0;
      while (_promotionOpen && !_disposed && guard < 600) {
        await Future.delayed(const Duration(milliseconds: 100));
        guard++;
      }
      if (_promotionOpen) choosePromotion(ChessPiece.queen);
    }
    if (_disposed || _phase != PlayPhase.playing) return;

    // Bot reply — pass human move quality for adaptive delay.
    final beforeBot = ChessEval.copyBoard(_board);
    final botMustAnswerCheck = ChessEval.isInCheck(beforeBot, false);
    BotMoveOutcome? botOutcome;
    try {
      botOutcome = await brain.playBotMove(
        humanVerdict: outcome.assessment.verdict,
        humanSwingCp: outcome.assessment.swingCp,
        wasCapture: outcome.assessment.wasCapture,
        botClockSec: botClockSec,
        humanClockSec: humanClockSec,
        botInCheck: botMustAnswerCheck,
      );
    } catch (_) {
      botOutcome = null;
    }
    if (_disposed) return;
    if (botOutcome != null) {
      _lastMove = botOutcome.move;
      final bMove = botOutcome.move;
      _moves.add(
        MoveRecord(
          move: bMove,
          uci: PieceGlyphs.uciFor(bMove),
          label: PieceGlyphs.prettyMove(bMove, beforeBot),
          glyph: PieceGlyphs.glyphFor(
            beforeBot[bMove.currentPosition.row][bMove.currentPosition.col],
          ),
          byHuman: false,
        ),
      );
      _reactToBotMove(botOutcome);
    }
    _botThinking = false;
    if (_phase == PlayPhase.playing) {
      _humanTurn = true;
      _armIdleNudge();
      _reactToPosition();
      _botHumanDecisions();
    }
    notifyListeners();
  }

  /// Builds the live game snapshot the behavior engine reasons over.
  BehaviorInput _behaviorState({MoveVerdict? lastHumanVerdict}) {
    return BehaviorInput(
      moveCount: _moves.length,
      botClockSec: botClockSec,
      humanClockSec: humanClockSec,
      evalWhiteCp: brain.whiteEvalCp(),
      lastHumanVerdict: lastHumanVerdict,
      isEndgame: ChessEval.isEndgameBoard(_board),
    );
  }

  /// After the bot moves, decide whether a human would resign or offer a
  /// draw in this position, and act on it.
  void _botHumanDecisions() {
    if (_phase != PlayPhase.playing) return;
    final behavior = brain.behavior;
    final input = BotMoveInput(state: _behaviorState());

    if (behavior.shouldResign(input)) {
      _botResigns();
      return;
    }
    if (!_botDrawOfferPending && behavior.shouldOfferDraw(input)) {
      _botDrawOfferPending = true;
      chat.onEvent(BotChatEvent.botOffersDraw, force: true);
      notifyListeners();
    }
  }

  Future<void> _botResigns() async {
    if (_phase != PlayPhase.playing) return;
    await chat.onEvent(BotChatEvent.botResigns, force: true);
    await _finishGame(
      GameResult.win,
      title: 'You won!',
      subtitle: '${bot.displayName} resigned',
    );
  }

  /// Human accepts the bot's outstanding draw offer.
  Future<void> acceptBotDraw() async {
    if (!_botDrawOfferPending || _phase != PlayPhase.playing) return;
    _botDrawOfferPending = false;
    await chat.onEvent(BotChatEvent.drawOfferAccepted, force: true);
    await _finishGame(
      GameResult.draw,
      title: 'Draw agreed',
      subtitle: '${bot.displayName} accepted your draw.',
    );
  }

  /// Human declines the bot's outstanding draw offer.
  Future<void> declineBotDraw() async {
    if (!_botDrawOfferPending) return;
    _botDrawOfferPending = false;
    await chat.onEvent(BotChatEvent.drawOfferDeclined, force: true);
    notifyListeners();
  }

  void _reactToHumanMove(HumanMoveOutcome outcome) {
    final a = outcome.assessment;
    if (a.gaveCheck) {
      chat.onEvent(BotChatEvent.humanCheck);
      return;
    }
    switch (a.verdict) {
      case MoveVerdict.blunder:
        chat.onEvent(BotChatEvent.humanBlunder);
        break;
      case MoveVerdict.mistake:
        chat.onEvent(BotChatEvent.humanMistake);
        break;
      case MoveVerdict.brilliant:
        chat.onEvent(BotChatEvent.humanBrilliant);
        break;
      default:
        if (a.wasCapture && a.capturedValue >= rookPower) {
          chat.onEvent(BotChatEvent.humanCapture);
        }
        break;
    }
  }

  void _reactToBotMove(BotMoveOutcome outcome) {
    final a = outcome.assessment;
    if (a == null) return;
    if (a.gaveCheck) {
      chat.onEvent(BotChatEvent.botCheck);
      return;
    }
    if (a.verdict == MoveVerdict.blunder) {
      chat.onEvent(BotChatEvent.botBlunder);
      return;
    }
    if (a.wasCapture && a.capturedValue >= rookPower) {
      chat.onEvent(BotChatEvent.botCapture);
    }
  }

  void _reactToPosition() {
    if (_moves.length <= 12) return;
    final evalWhite = brain.whiteEvalCp();
    if (evalWhite >= 600) {
      chat.onEvent(BotChatEvent.botLosingBig);
    } else if (evalWhite <= -600) {
      chat.onEvent(BotChatEvent.botWinningBig);
    } else {
      chat.emitBanter(winning: evalWhite < -100);
    }
  }

  Future<void> offerDraw() async {
    if (_phase != PlayPhase.playing) return;
    final evalWhite = brain.whiteEvalCp();
    // Bot accepts when clearly worse in a real game, else declines.
    final accept = evalWhite > 350 && _moves.length >= 24;
    if (accept) {
      await chat.onEvent(BotChatEvent.drawOfferAccepted, force: true);
      await _finishGame(
        GameResult.draw,
        title: 'Draw agreed',
        subtitle: '${bot.displayName} accepted your draw offer.',
      );
    } else {
      await chat.onEvent(BotChatEvent.drawOfferDeclined);
    }
  }

  Future<void> resign() async {
    if (_phase != PlayPhase.playing) return;
    await _finishGame(
      GameResult.loss,
      title: 'You lost!',
      subtitle: 'by resignation',
    );
  }

  Future<void> timeout({required bool humanTimedOut}) async {
    if (_phase != PlayPhase.playing) return;
    await _finishGame(
      humanTimedOut ? GameResult.loss : GameResult.win,
      title: humanTimedOut ? 'You lost!' : 'You won!',
      subtitle: humanTimedOut ? 'on time' : '${bot.displayName} ran out of time',
    );
  }

  void choosePromotion(ChessPiece piece) {
    final pos = _promotionPos;
    if (pos != null) {
      brain.setPromotion(pos, piece);
    }
    _promotionPos = null;
    _promotionOpen = false;
    notifyListeners();
  }

  Future<void> _onEngineGameOver(GameOver status) async {
    if (_phase != PlayPhase.playing) return;
    // The engine fires game-over BEFORE the board callback, so refresh from
    // the live board first (the local copy is one move stale here).
    _board = ChessEval.copyBoard(brain.board);
    _refreshDerived();

    // Stalemate correction: the engine reports "opponent has no legal moves"
    // as a win for the mover even when the opponent is NOT in check.
    if (status == GameOver.whiteWins || status == GameOver.blackWins) {
      final loserIsWhite = status == GameOver.blackWins;
      final loserInCheck = ChessEval.isInCheck(_board, loserIsWhite);
      if (!loserInCheck) {
        _isStalemate = true;
        await _finishGame(
          GameResult.draw,
          title: 'Stalemate — draw',
          subtitle: 'No legal moves, but the king is safe.',
        );
        return;
      }
    }
    switch (status) {
      case GameOver.whiteWins:
        await _finishGame(
          GameResult.win,
          title: 'You won!',
          subtitle: 'by checkmate',
        );
        break;
      case GameOver.blackWins:
        await _finishGame(
          GameResult.loss,
          title: 'You lost!',
          subtitle: 'by checkmate',
        );
        break;
      case GameOver.draw:
        await _finishGame(
          GameResult.draw,
          title: 'Draw',
          subtitle: 'Dead even. Neither side blinked.',
        );
        break;
    }
  }

  Future<void> _finishGame(
    GameResult result, {
    required String title,
    required String subtitle,
  }) async {
    if (_phase == PlayPhase.gameOver) return;
    _phase = PlayPhase.gameOver;
    _humanTurn = false;
    _botThinking = false;
    _cancelIdle();
    _resultTitle = title;
    _resultSubtitle = subtitle;
    _playerResult = result;

    final profile = profileRepo.profile;
    final delta = MatchPointSystem.ratingDelta(
      difficulty: matchDifficulty,
      result: result,
    );
    var newRating = profile.rating + delta;
    if (newRating < 100) newRating = 100;
    _eloDelta = newRating - profile.rating;
    _newRating = newRating;

    final record = GameRecord(
      id: '${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(99999)}',
      playedAt: DateTime.now(),
      botName: bot.displayName,
      botIso: bot.countryIso,
      botRating: bot.rating,
      result: result,
      eloBefore: profile.rating,
      eloAfter: newRating,
      moves: fullMoves,
      userBlunders: brain.tracker.userBlunders,
      userAccuracy: brain.tracker.userAccuracy,
      botAccuracy: brain.tracker.botAccuracy,
      userMistakes: brain.tracker.userMistakes,
      userInaccuracies: brain.tracker.userInaccuracies,
      userChecks: brain.tracker.userChecks,
      botBlunders: brain.tracker.botBlunders,
      botMistakes: brain.tracker.botMistakes,
      botInaccuracies: brain.tracker.botInaccuracies,
      botChecks: brain.tracker.botChecks,
    );
    await profileRepo.applyGameResult(
      result: result,
      newRating: newRating,
      record: record,
    );

    // Lock chat after game ends — no more user messages accepted.
    chat.lock();

    // Result line lands instantly so it is visible with the dialog.
    switch (result) {
      case GameResult.win:
        await chat.onEvent(
          _isStalemate ? BotChatEvent.gameStalemate : BotChatEvent.gameWinHuman,
          force: true,
          instant: true,
        );
        break;
      case GameResult.loss:
        await chat.onEvent(BotChatEvent.gameWinBot, force: true, instant: true);
        break;
      case GameResult.draw:
        await chat.onEvent(
          _isStalemate ? BotChatEvent.gameStalemate : BotChatEvent.gameDraw,
          force: true,
          instant: true,
        );
        break;
    }
    if (_disposed) return;
    notifyListeners();
  }

  void _armIdleNudge() {
    _cancelIdle();
    _idleTimer = Timer(const Duration(seconds: 50), () {
      if (_disposed || _phase != PlayPhase.playing || !_humanTurn) return;
      chat.onEvent(BotChatEvent.idleNudge);
      _armIdleNudge();
    });
  }

  void _cancelIdle() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  void sendChat(String text) {
    chat.onUserMessage(text);
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelIdle();
    chat.dispose();
    brain.dispose();
    super.dispose();
  }
}
