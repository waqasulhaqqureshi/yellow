import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/arena_theme.dart';
import '../../../matchmaking/matchmaking_controller.dart';
import '../../../profile/data/profile_repository.dart';
import 'game_screen.dart';

/// Rating-aware matchmaking presented in the same focused teal arena style as
/// the reference. The data source remains online-ready and falls back to a bot.
class SearchingScreen extends StatefulWidget {
  final ProfileRepository profileRepo;
  final String timeControl;

  const SearchingScreen({
    super.key,
    required this.profileRepo,
    this.timeControl = 'Blitz',
  });

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  late final MatchmakingController _search;
  late final AnimationController _pulse;
  Timer? _enterTimer;

  @override
  void initState() {
    super.initState();
    _search = MatchmakingController();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _search.addListener(_onSearch);
    _search.start(widget.profileRepo.profile);
  }

  void _onSearch() {
    if (!mounted) return;
    if (_search.phase == SearchPhase.found && _enterTimer == null) {
      _enterTimer = Timer(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        final bot = _search.bot;
        if (bot == null) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (routeContext) => GameScreen(
              bot: bot,
              profileRepo: widget.profileRepo,
              timeControl: widget.timeControl,
            ),
          ),
        );
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _enterTimer?.cancel();
    _search.removeListener(_onSearch);
    _search.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _search.phase != SearchPhase.searching,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        body: DecoratedBox(
          decoration: ArenaTheme.pageDecoration(),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _search,
              builder: (context, child) => _searchingView(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _searchingView() {
    final elapsed = _search.elapsed;
    final seconds =
        '${elapsed.inMinutes}:${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      child: Column(
        children: [
          const Spacer(flex: 2),
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => CustomPaint(
              painter: _SearchPulsePainter(_pulse.value),
              child: const SizedBox(
                width: 178,
                height: 178,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: ArenaTheme.orangeGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                      ],
                    ),
                    child: SizedBox(
                      width: 76,
                      height: 76,
                      child: Center(
                        child: Text('♞', style: TextStyle(color: Colors.white, fontSize: 40)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Finding opponent',
            style: TextStyle(
              color: ArenaTheme.ink,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Matching you with a worthy rival…',
            style: TextStyle(color: ArenaTheme.muted, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: ArenaTheme.glassCard(),
            child: Row(
              children: [
                Image.asset(
                  _controlAsset(),
                  width: 42,
                  height: 42,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(Icons.timer_outlined, size: 34),
                ),
                const SizedBox(width: 12),
                Text(
                  widget.timeControl,
                  style: const TextStyle(
                    color: ArenaTheme.ink,
                    fontFamily: 'serif',
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Text(
                  _controlDetail(),
                  style: const TextStyle(color: ArenaTheme.muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: ArenaTheme.cardDeep.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              children: [
                Text(
                  seconds,
                  style: const TextStyle(
                    color: ArenaTheme.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'E L A P S E D',
                  style: TextStyle(
                    color: ArenaTheme.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _cancel,
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  String _controlAsset() {
    switch (widget.timeControl) {
      case 'Rapid':
        return 'timecontrol/1.png';
      case 'Chill':
        return 'timecontrol/2.png';
      case 'Tempo':
        return 'timecontrol/4.png';
      case 'Turbo':
        return 'timecontrol/5.png';
      case 'Bullet':
        return 'timecontrol/6.png';
      default:
        return 'timecontrol/3.png';
    }
  }

  String _controlDetail() {
    switch (widget.timeControl) {
      case 'Rapid':
        return '10 min';
      case 'Chill':
        return '60 seconds/move';
      case 'Tempo':
        return '20 seconds/move';
      case 'Turbo':
        return '3 min';
      case 'Bullet':
        return '2 min +1 sec';
      default:
        return '5 min +3 sec/move';
    }
  }

  void _cancel() {
    _search.cancel();
    if (mounted) Navigator.of(context).pop();
  }
}

class _SearchPulsePainter extends CustomPainter {
  final double progress;

  const _SearchPulsePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1;
      final radius = 43 + phase * 44;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = ArenaTheme.gold.withValues(alpha: (1 - phase) * 0.55);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SearchPulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
