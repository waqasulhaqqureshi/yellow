import 'dart:async';
import 'dart:math' show pow;

import 'package:flutter/material.dart';
import 'package:genetom_chess_engine/genetom_chess_engine.dart';

import '../../../../core/theme/arena_theme.dart';
import '../../../../core/theme/board_themes.dart';
import '../../../../core/utils/sound_fx.dart';
import '../../../../core/widgets/chess_piece_image.dart';
import '../../../../core/widgets/flag_avatar.dart';
import '../../../bot/domain/bot_personality.dart';
import '../../../bot/domain/bot_profile.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../rating/match_point_system.dart';
import '../../domain/game_result.dart';
import '../game_controller.dart';
import '../widgets/chat_sheet.dart';
import '../widgets/chess_board_widget.dart';
import '../widgets/game_over_dialog.dart';
import '../widgets/player_bar.dart';
import '../widgets/promotion_dialog.dart';
import 'review_screen.dart';
import 'searching_screen.dart';

/// Live timed game vs a bot: player clocks, image board, chat, settings,
/// opponent actions and post-game review.
class GameScreen extends StatefulWidget {
  final BotProfile bot;
  final ProfileRepository profileRepo;
  final String timeControl;

  const GameScreen({
    super.key,
    required this.bot,
    required this.profileRepo,
    this.timeControl = 'Blitz',
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _controller;
  bool _overShown = false;
  bool _promoShown = false;
  bool _introStarted = false;
  int _introStage = 0;
  Timer? _introTimer;
  Timer? _clockTimer;
  late int _humanSeconds;
  late int _botSeconds;
  int _clockMoveCount = 0;
  bool _timeoutSent = false;

  // In-game settings mirror the reference panel and affect live behavior.
  bool _soundOn = true;
  bool _showLastMove = true;
  bool _pieceAnimation = true;
  bool _showMoveHelp = true;
  bool _confirmMoves = false;
  bool _autoPromoteQueen = true;
  bool _showChat = true;
  bool _showEvalBar = false;
  int _seenMoves = 0;
  bool _seenCheck = false;
  bool _fxOver = false;

  @override
  void initState() {
    super.initState();
    _humanSeconds = _initialClockSeconds;
    _botSeconds = _initialClockSeconds;
    _clockTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _tickClock(),
    );
    _controller = GameController(
      bot: widget.bot,
      profileRepo: widget.profileRepo,
      timeControl: widget.timeControl,
    );
    _controller.addListener(_onController);
    _controller.init();
    // Warm the piece art so the very first painted move is the real image.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PieceAssetPreloader.warm(context);
    });
  }

  int get _initialClockSeconds {
    switch (widget.timeControl) {
      case 'Rapid':
        return 10 * 60;
      case 'Chill':
        return 60;
      case 'Tempo':
        return 20;
      case 'Turbo':
        return 3 * 60;
      case 'Bullet':
        return 2 * 60;
      default:
        return 5 * 60;
    }
  }

  int get _incrementSeconds {
    switch (widget.timeControl) {
      case 'Blitz':
        return 3;
      case 'Bullet':
        return 1;
      default:
        return 0;
    }
  }

  bool get _perMoveClock =>
      widget.timeControl == 'Chill' || widget.timeControl == 'Tempo';

  void _tickClock() {
    if (!mounted ||
        _controller.phase != PlayPhase.playing ||
        _introStage != 2 ||
        _timeoutSent) {
      return;
    }
    setState(() {
      if (_controller.humanTurn) {
        _humanSeconds -= 1;
        if (_humanSeconds <= 0) {
          _humanSeconds = 0;
          _timeoutSent = true;
          _controller.timeout(humanTimedOut: true);
        }
      } else {
        _botSeconds -= 1;
        if (_botSeconds <= 0) {
          _botSeconds = 0;
          _timeoutSent = true;
          _controller.timeout(humanTimedOut: false);
        }
      }
      _controller.updateClocks(human: _humanSeconds, bot: _botSeconds);
    });
  }

  void _syncClockAfterMove() {
    final moveCount = _controller.moves.length;
    if (moveCount == _clockMoveCount) return;
    _clockMoveCount = moveCount;
    // The current turn belongs to the other side, so credit/reset the player
    // who just completed the move.
    if (_controller.humanTurn) {
      _botSeconds = _perMoveClock
          ? _initialClockSeconds
          : _botSeconds + _incrementSeconds;
    } else {
      _humanSeconds = _perMoveClock
          ? _initialClockSeconds
          : _humanSeconds + _incrementSeconds;
    }
  }

  void _onController() {
    if (!mounted) return;
    _syncClockAfterMove();
    _playFx();
    if (_controller.phase == PlayPhase.playing && !_introStarted) {
      _introStarted = true;
      _introTimer = Timer(const Duration(milliseconds: 2200), () {
        if (!mounted || _controller.phase != PlayPhase.playing) return;
        setState(() => _introStage = 1);
      });
    }
    if (_controller.phase == PlayPhase.gameOver && !_overShown) {
      _overShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showGameOver();
      });
    }
    if (_controller.promotionOpen && !_promoShown) {
      if (_autoPromoteQueen) {
        _controller.choosePromotion(ChessPiece.queen);
        return;
      }
      _promoShown = true;
      PromotionDialog.show(context, (piece) {
        _promoShown = false;
        _controller.choosePromotion(piece);
      });
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _clockTimer?.cancel();
    _controller.removeListener(_onController);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final chrome =
            boardThemeFor(widget.profileRepo.profile.boardThemeId);
        final introVisible =
            _controller.phase == PlayPhase.playing && _introStage < 2;
        return PopScope(
          canPop: _controller.phase == PlayPhase.gameOver,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _confirmExit();
          },
          child: Stack(
            children: [
              Scaffold(
                appBar: AppBar(
                  toolbarHeight: 64,
                  backgroundColor: chrome.chromeStops[1],
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(gradient: chrome.chromeGradient),
                  ),
                  leadingWidth: 64,
                  leading: TextButton(
                    onPressed: _confirmExit,
                    child: const Text(
                      '←',
                      style: TextStyle(
                        color: ArenaTheme.ink,
                        fontSize: 36,
                        height: 1,
                      ),
                    ),
                  ),
                  title: const SizedBox.shrink(),
                  actions: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          tooltip: 'Open chat',
                          onPressed: _showChat &&
                                  _controller.phase == PlayPhase.playing &&
                                  _introStage == 2
                              ? _openChat
                              : null,
                          icon: const Icon(Icons.chat_bubble_outline, size: 27),
                        ),
                        if (_controller.chat.unread > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE03131),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  _controller.chat.unread > 9
                                      ? '9'
                                      : '${_controller.chat.unread}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        TextButton(
                          onPressed: _controller.phase == PlayPhase.playing &&
                                  _introStage == 2
                              ? _showPlayerActions
                              : null,
                          child: const Text(
                            '☰',
                            style: TextStyle(color: ArenaTheme.ink, fontSize: 28),
                          ),
                        ),
                        if (_controller.botDrawOfferPending)
                          Positioned(
                            right: 2,
                            top: 5,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE03131),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Center(
                                child: Text(
                                  '1',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: TextButton(
                        onPressed: _controller.phase == PlayPhase.playing &&
                                _introStage == 2
                            ? _showGameOptions
                            : null,
                        child: const Text(
                          '⚙',
                          style: TextStyle(color: ArenaTheme.ink, fontSize: 28),
                        ),
                      ),
                    ),
                  ],
                ),
                body: _controller.phase == PlayPhase.loading
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: chrome.chromeGradient,
                        ),
                        child: const Center(child: CircularProgressIndicator()),
                      )
                    : _body(),
              ),
              if (introVisible)
                Positioned.fill(child: _introOverlay()),
            ],
          ),
        );
      },
    );
  }

  Widget _introOverlay() {
    final difficulty = _controller.matchDifficulty;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width - 40,
          constraints: const BoxConstraints(maxWidth: 400),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFCFE4FF), Color(0xFFE7F1FF), Color(0xFFFBFDFF)],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFD0DDE8)),
            boxShadow: const [
              BoxShadow(color: Color(0x330B63CE), blurRadius: 24, offset: Offset(0, 10)),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: const TextStyle(decoration: TextDecoration.none),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              child: _introStage == 0 ? _introFound(difficulty) : _introReady(difficulty),
            ),
          ),
        ),
      ),
    );
  }

  Widget _introFound(MatchDifficulty difficulty) {
    return Padding(
      key: const ValueKey<int>(0),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'O P P O N E N T   F O U N D',
            style: TextStyle(
              color: Color(0xFF0B63CE),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 20),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0B63CE), width: 2.5),
                ),
                child: BotAvatar(seed: widget.bot.avatarSeed, size: 84),
              ),
              Positioned(
                right: -4,
                bottom: 2,
                child: CountryFlag(
                  isoCode: widget.bot.countryIso,
                  width: 30,
                  height: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.bot.displayName,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.bot.countryName,
            style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip('${widget.bot.rating}', const Color(0xFF16865B)),
              const SizedBox(width: 8),
              _chip(difficulty.label, const Color(0xFF0B63CE)),
              const SizedBox(width: 8),
              _chip(widget.bot.personality.label, const Color(0xFF667085)),
            ],
          ),
          const SizedBox(height: 22),
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(color: Color(0xFF0B63CE), strokeWidth: 3),
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.bot.name} is setting up the board…',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _introReady(MatchDifficulty difficulty) {
    return Padding(
      key: const ValueKey<int>(1),
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '♞',
            style: TextStyle(color: Color(0xFF0B63CE), fontSize: 34),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ready to play?',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.timeControl} · vs ${widget.bot.displayName}',
            style: const TextStyle(color: Color(0xFF667085), fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _stakeCard(
                  '+${difficulty.winPoints}',
                  'If you win',
                  const Color(0xFF16865B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _stakeCard(
                  '-${difficulty.lossPenalty}',
                  'If you lose',
                  const Color(0xFFC4474F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: ArenaTheme.orangeGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => setState(() => _introStage = 2),
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Text(
                      'Start game',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Good luck — play fair, think ahead.',
            style: TextStyle(color: Color(0xFF667085), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _stakeCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F8FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF667085), fontSize: 12)),
        ],
      ),
    );
  }

  String _clockText(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Widget _body() {
    final c = _controller;
    final human = widget.profileRepo.profile;
    final chrome = boardThemeFor(human.boardThemeId);
    final stops = chrome.chromeStops;
    final whiteCp = c.captured.materialWhiteCp;
    final pawns = (whiteCp.abs() / 100).round();
    return DecoratedBox(
      decoration: BoxDecoration(gradient: chrome.chromeGradient),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // The reference board always spans the complete screen width. A
          // short/wide preview scrolls vertically instead of shrinking it.
          final boardSide = constraints.maxWidth;
          final opponentBar = PlayerBar(
            name: widget.bot.displayName,
            detail: '(${widget.bot.rating})',
            avatarSeed: widget.bot.avatarSeed,
            isoCode: widget.bot.countryIso,
            captured: c.captured.byBot,
            scoreText: whiteCp < -50 ? '+$pawns' : null,
            active: c.phase == PlayPhase.playing && !c.humanTurn,
            thinking: c.botThinking,
            inCheck: c.botInCheck,
            clockText: _clockText(_botSeconds),
            pieceStyle: human.pieceStyle,
            barTop: stops[0],
            barBottom: stops[2],
          );
          final board = SizedBox(
            width: boardSide,
            height: boardSide,
            child: ChessBoardWidget(
              board: c.board,
              selected: c.selected,
              validTargets: _showMoveHelp
                  ? c.validTargets
                  : const <CellPosition>[],
              lastMove: _showLastMove ? c.lastMove : null,
              humanInCheck: c.humanInCheck,
              botInCheck: c.botInCheck,
              animatePieces: _pieceAnimation,
              boardThemeId: human.boardThemeId,
              pieceStyle: human.pieceStyle,
              onTap: _handleBoardTap,
            ),
          );
          final boardWithEval = _showEvalBar
              ? Stack(
                  children: [
                    board,
                    Positioned(
                      left: 3,
                      top: 3,
                      bottom: 3,
                      child: _evalBar(whiteCp),
                    ),
                  ],
                )
              : board;
          final humanBar = PlayerBar(
            name: human.name,
            detail: '(${human.rating})',
            avatarSeed: human.avatarSeed,
            captured: c.captured.byHuman,
            scoreText: whiteCp > 50 ? '+$pawns' : null,
            active: c.phase == PlayPhase.playing && c.humanTurn,
            inCheck: c.humanInCheck,
            human: true,
            clockText: _clockText(_humanSeconds),
            pieceStyle: human.pieceStyle,
            lowClock: _humanSeconds < 20,
            pulse: _humanSeconds.isOdd,
            barTop: stops[0],
            barBottom: stops[2],
          );
          final shortViewport = constraints.maxHeight < boardSide + 220;
          if (shortViewport) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  opponentBar,
                  boardWithEval,
                  humanBar,
                  const SizedBox(height: 140),
                ],
              ),
            );
          }
          return Column(
            children: [
              opponentBar,
              boardWithEval,
              humanBar,
              const Expanded(child: SizedBox.shrink()),
            ],
          );
        },
      ),
    );
  }

  void _showMoveHistory() {
    final moves = _controller.moves;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SizedBox(
        height: 360,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Move history',
                      style: TextStyle(
                        color: ArenaTheme.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text('☰', style: TextStyle(fontSize: 24)),
                ],
              ),
            ),
            Divider(height: 1, color: ArenaTheme.line),
            Expanded(
              child: moves.isEmpty
                  ? const Center(
                      child: Text(
                        'No moves yet',
                        style: TextStyle(color: ArenaTheme.muted),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(14),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 4.2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: moves.length,
                      itemBuilder: (context, index) {
                        final number = index ~/ 2 + 1;
                        final prefix = index.isEven ? '$number.' : '…';
                        return Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: ArenaTheme.cardDeep,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$prefix  ${moves[index].label}',
                            style: const TextStyle(
                              color: ArenaTheme.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBoardTap(int row, int col) {
    final selected = _controller.selected;
    final isLegalTarget = _controller.validTargets.any(
      (target) => target.row == row && target.col == col,
    );
    if (!_confirmMoves || selected == null || !isLegalTarget) {
      _controller.onSquareTap(row, col);
      return;
    }
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm move?'),
        content: const Text(
          'Move the selected piece to this square?',
          style: TextStyle(color: ArenaTheme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Move'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (!mounted || confirmed != true) return;
      final stillSelected = _controller.selected;
      final stillLegal = _controller.validTargets.any(
        (target) => target.row == row && target.col == col,
      );
      if (_controller.phase == PlayPhase.playing &&
          stillSelected != null &&
          stillSelected.row == selected.row &&
          stillSelected.col == selected.col &&
          stillLegal) {
        _controller.onSquareTap(row, col);
      }
    });
  }

  void _showPlayerActions() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dialogContext) => Dialog(
        backgroundColor: ArenaTheme.card.withValues(alpha: 0.92),
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: ArenaTheme.line),
        ),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_controller.botDrawOfferPending)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E5BCE).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF1E5BCE).withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.handshake_rounded,
                        color: Color(0xFF1E5BCE),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.bot.name} offers a draw',
                          style: const TextStyle(
                            color: ArenaTheme.ink,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _controller.declineBotDraw();
                        },
                        child: const Text('Decline'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          _controller.acceptBotDraw();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E5BCE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: const Text('Accept'),
                      ),
                    ],
                  ),
                ),
              _playerActionRow(
                emoji: '☷',
                label: 'Move history',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _showMoveHistory();
                },
              ),
              _playerActionRow(
                emoji: _showChat ? '🚫' : '💬',
                label: _showChat
                    ? 'Mute ${widget.bot.name}'
                    : 'Unmute ${widget.bot.name}',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  setState(() => _showChat = !_showChat);
                },
              ),
              _playerActionRow(
                emoji: '🤝',
                label: 'Offer Draw',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _controller.offerDraw();
                },
              ),
              _playerActionRow(
                emoji: '👥',
                label: 'Send friend request',
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: ArenaTheme.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Friend requests', style: TextStyle(color: ArenaTheme.ink)),
                      content: const Text(
                        'Friend requests will arrive with online multiplayer.',
                        style: TextStyle(color: ArenaTheme.muted),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              _playerActionRow(
                emoji: '⚑',
                label: 'Resign',
                showDivider: false,
                onTap: () {
                  Navigator.of(dialogContext).pop();
                  _confirmResign();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _playerActionRow({
    required String emoji,
    required String label,
    required VoidCallback onTap,
    bool showDivider = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(emoji, style: const TextStyle(fontSize: 27)),
                ),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: ArenaTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) Divider(height: 1, color: ArenaTheme.line),
      ],
    );
  }

  void _showGameOptions() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFBFDFF), Color(0xFFF2F7FF)],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFD0DDE8)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x330B63CE),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Settings',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                _settingRow(
                  'Sound',
                  _soundOn,
                  (value) => _updateSetting(
                    setDialogState,
                    () => _soundOn = value,
                  ),
                ),
                _settingRow(
                  'Show last move',
                  _showLastMove,
                  (value) => _updateSetting(
                    setDialogState,
                    () => _showLastMove = value,
                  ),
                ),
                _settingRow(
                  'Piece animation',
                  _pieceAnimation,
                  (value) => _updateSetting(
                    setDialogState,
                    () => _pieceAnimation = value,
                  ),
                ),
                _settingRow(
                  'Show move help',
                  _showMoveHelp,
                  (value) => _updateSetting(
                    setDialogState,
                    () => _showMoveHelp = value,
                  ),
                ),
                _settingRow(
                  'Confirm moves',
                  _confirmMoves,
                  (value) => _updateSetting(
                    setDialogState,
                    () => _confirmMoves = value,
                  ),
                ),
                _settingRow(
                  'Auto promote queen',
                  _autoPromoteQueen,
                  (value) => _updateSetting(
                    setDialogState,
                    () => _autoPromoteQueen = value,
                  ),
                ),
                  _settingRow(
                    'Show chat',
                    _showChat,
                    (value) => _updateSetting(
                      setDialogState,
                      () => _showChat = value,
                    ),
                  ),
                  _settingRow(
                    'Eval bar',
                    _showEvalBar,
                    (value) => _updateSetting(
                      setDialogState,
                      () => _showEvalBar = value,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingRow(
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF0B63CE),
            activeTrackColor: const Color(0xFF0B63CE).withValues(alpha: 0.25),
            inactiveThumbColor: const Color(0xFF98A2B3),
            inactiveTrackColor: const Color(0xFFE4E9F0),
          ),
        ],
      ),
    );
  }

  void _updateSetting(
    StateSetter setDialogState,
    VoidCallback update,
  ) {
    if (!mounted) return;
    setState(update);
    setDialogState(() {});
  }

  /// Sound + haptic feedback driven by controller changes, gated by the
  /// Sound setting. Move / capture / check / game-end events.
  void _playFx() {
    final c = _controller;
    SoundFx.enabled = _soundOn;
    final n = c.moves.length;
    if (n > _seenMoves) {
      final last = c.moves[n - 1];
      if (last.label.contains('x')) {
        SoundFx.capture();
      } else {
        SoundFx.move();
      }
      _seenMoves = n;
    }
    final checkNow = c.humanInCheck || c.botInCheck;
    if (checkNow && !_seenCheck) SoundFx.check();
    _seenCheck = checkNow;
    if (c.phase == PlayPhase.gameOver && !_fxOver) {
      _fxOver = true;
      if (c.playerResult == GameResult.win) {
        SoundFx.win();
      } else if (c.playerResult == GameResult.loss) {
        SoundFx.lose();
      } else {
        SoundFx.draw();
      }
    }
  }

  /// Subtle live eval bar overlaid on the board's left edge.
  Widget _evalBar(int whiteCp) {
    final white = (1 / (1 + pow(10, -whiteCp / 400))).clamp(0.04, 0.96);
    return Container(
      width: 6,
      decoration: BoxDecoration(
        color: const Color(0xB320242B),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: white,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xE6F5F5F5),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
          ),
        ),
      ),
    );
  }

  Future<void> _openChat() async {
    final chat = _controller.chat;
    chat.chatOpen = true;
    chat.markRead();
    await ChatSheet.show(context, chat);
    chat.chatOpen = false;
  }

  void _showGameOver() {
    final c = _controller;
    final result = c.playerResult;
    if (result == null) return;
    GameOverDialog.show(
      context,
      bot: widget.bot,
      result: result,
      title: c.resultTitle,
      subtitle: c.resultSubtitle,
      humanName: widget.profileRepo.profile.name,
      humanAvatarSeed: widget.profileRepo.profile.avatarSeed,
      eloDelta: c.eloDelta ?? 0,
      newRating: c.newRating ?? widget.profileRepo.profile.rating,
      moves: c.fullMoves,
      difficultyLabel: c.matchDifficulty.label,
      difficultyPoints: c.matchDifficulty.lossPenalty,
      humanAccuracy: c.brain.tracker.userAccuracy,
      botAccuracy: c.brain.tracker.botAccuracy,
      humanMoves: c.brain.tracker.userMoves,
      botMoves: c.brain.tracker.botMoves,
      blunders: c.brain.tracker.userBlunders,
      mistakes: c.brain.tracker.userMistakes,
      inaccuracies: c.brain.tracker.userInaccuracies,
      checks: c.brain.tracker.userChecks,
      botBlunders: c.brain.tracker.botBlunders,
      botMistakes: c.brain.tracker.botMistakes,
      botInaccuracies: c.brain.tracker.botInaccuracies,
      botChecks: c.brain.tracker.botChecks,
      onReview: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReviewScreen(
              moves: c.moves,
              botName: widget.bot.displayName,
            ),
          ),
        );
      },
      onNewOpponent: () {
        Navigator.of(context).pop();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (routeContext) => SearchingScreen(
              profileRepo: widget.profileRepo,
              timeControl: widget.timeControl,
            ),
          ),
        );
      },
      onHome: () {
        Navigator.of(context).popUntil((r) => r.isFirst);
      },
    );
  }

  void _confirmResign() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArenaTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Resign this game?',
          style: TextStyle(color: ArenaTheme.ink),
        ),
        content: const Text(
          'This counts as a loss and deducts your match points.',
          style: TextStyle(color: ArenaTheme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _controller.resign();
            },
            style: FilledButton.styleFrom(backgroundColor: ArenaTheme.danger),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
  }

  void _confirmExit() {
    if (_controller.phase != PlayPhase.playing) {
      Navigator.of(context).pop();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ArenaTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Leave the arena?',
          style: TextStyle(color: ArenaTheme.ink),
        ),
        content: const Text(
          'Leaving counts as a resignation. You can review the game summary before returning home.',
          style: TextStyle(color: ArenaTheme.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Stay'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _controller.resign();
            },
            style: FilledButton.styleFrom(backgroundColor: ArenaTheme.danger),
            child: const Text('Resign & view result'),
          ),
        ],
      ),
    );
  }
}
