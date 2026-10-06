import 'dart:math' show pi;

import 'package:flutter/material.dart';

import '../../../../core/theme/board_themes.dart';
import '../../../../core/widgets/flag_avatar.dart';
import '../../../../core/widgets/chess_piece_image.dart';
import '../../../chat/group/group_screens.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../profile/domain/game_record.dart';
import '../../../rating/elo_service.dart';
import '../../domain/game_result.dart';
import 'searching_screen.dart';

/// Chess.com-style home screen matching updated.jpg reference.
/// Order: Top header -> Rating/Streak -> Play Online -> Find Opponent -> Group Chat (just above nav) -> Bottom nav
class HomeScreen extends StatefulWidget {
  final ProfileRepository profileRepo;

  const HomeScreen({super.key, required this.profileRepo});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  String _timeControl = 'Blitz';
  bool _globalRankings = true;

  ProfileRepository get profileRepo => widget.profileRepo;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: profileRepo,
      builder: (context, child) => Scaffold(
        backgroundColor: const Color(0xFFEAF2FF),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFE8F1FF), Color(0xFFF0F6FF), Color(0xFFEAF2FF)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _tab,
                    children: [
                      _playPage(),
                      _friendsPage(),
                      _rankingsPage(),
                      _profilePage(),
                    ],
                  ),
                ),
                _bottomNavigation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playPage() {
    return SingleChildScrollView(
      key: const PageStorageKey<String>('play-page'),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          _topHeader(),
          const SizedBox(height: 14),
          _ratingStreakCard(),
          const SizedBox(height: 14),
          _playOnlineCard(),
          const SizedBox(height: 16),
          _RotatingRay(child: _findOpponentButton()),
          Builder(
            builder: (context) {
              final h = MediaQuery.of(context).size.height;
              return SizedBox(height: h * 0.16);
            },
          ),
          GestureDetector(
            onTap: _comingSoon,
            child: _groupChatPill(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _topHeader() {
    final p = profileRepo.profile;
    return Row(
      children: [
        GestureDetector(
          onTap: _showEditProfile,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: BotAvatar(seed: p.avatarSeed, size: 56),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                  child: const CountryFlag(isoCode: 'PL', width: 28, height: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _showEditProfile,
            child: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
        _customizeButton(),
        const SizedBox(width: 8),
        _statsButton(),
      ],
    );
  }

  Widget _customizeButton() {
    return GestureDetector(
      onTap: _customizeProfile,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.palette_outlined,
          color: Color(0xFF0B63CE),
          size: 20,
        ),
      ),
    );
  }

  Widget _statsButton() {
    return InkWell(
      onTap: _showStatsSheet,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD0DDE8), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Image.asset(
            'assets/images/home/stats_button.png',
            height: 36,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28,
                    height: 20,
                    child: CustomPaint(painter: _StatsChartPainter()),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Stats',
                    style: TextStyle(
                      color: Color(0xFF1E5BCE),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
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

  Widget _ratingStreakCard() {
    final p = profileRepo.profile;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Your Rating',
                      style: TextStyle(
                        color: Color(0xFF6B7FA3),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Image.asset(
                      'assets/images/home/crown.png',
                      width: 20,
                      height: 20,
                      errorBuilder: (_, _, _) => const Text('👑', style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${p.rating}',
                  style: const TextStyle(
                    color: Color(0xFF0A1E4A),
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 1.2,
            height: 56,
            color: const Color(0xFFE0E8F0),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/home/flame.gif',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Image.asset(
                        'assets/images/home/flame.png',
                        width: 32,
                        height: 32,
                        errorBuilder: (context, error, stackTrace) => const Text('🔥', style: TextStyle(fontSize: 32)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${profileRepo.activeDayStreak}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Day Streak',
                  style: TextStyle(
                    color: Color(0xFF6B7FA3),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ],
          ),
        ],
      ),
    );
  }

  Widget _playOnlineCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B63CE),
        borderRadius: BorderRadius.circular(20),
        image: const DecorationImage(
          image: AssetImage('assets/images/home/play_bg.png'),
          fit: BoxFit.cover,
          opacity: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B63CE).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Play Online',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR ACCURACY',
                      style: TextStyle(
                        color: Color(0xFFA8C4E8),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _dartIcon(),
                        const SizedBox(width: 10),
                        const Text(
                          '72%',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 58,
                color: Colors.white.withValues(alpha: 0.22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: _pickTimeControl,
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TIME CONTROLS',
                        style: TextStyle(
                          color: Color(0xFFA8C4E8),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _timeControlIcon(),
                          const SizedBox(width: 10),
                          const Text(
                            'Select',
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '>',
                            style: TextStyle(
                              color: Color(0xFFFFD54F),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A4A9E).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.timer_outlined, color: Color(0xFF5AFF8A), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _timeLabel(_timeControl),
                              style: const TextStyle(
                                color: Color(0xFF5AFF8A),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dartIcon() {
    return Image.asset(
      'assets/images/home/dart.png',
      width: 44,
      height: 44,
      errorBuilder: (_, _, _) => Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          color: Color(0xFF1A8CFF),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.adjust, color: Colors.white, size: 28),
      ),
    );
  }

  Widget _lightningIcon() {
    return Image.asset(
      'assets/images/home/lightning.png',
      width: 42,
      height: 42,
      errorBuilder: (_, _, _) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A8A7A), Color(0xFF0E5A6E)],
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.bolt, color: Color(0xFF5AD8FF), size: 26),
      ),
    );
  }

  /// Icon beside "Select" that changes with the active time-control mode.
  Widget _timeControlIcon() {
    int idx;
    switch (_timeControl) {
      case 'Rapid':
        idx = 1;
        break;
      case 'Chill':
        idx = 2;
        break;
      case 'Blitz':
        idx = 3;
        break;
      case 'Tempo':
        idx = 4;
        break;
      case 'Turbo':
        idx = 5;
        break;
      case 'Bullet':
        idx = 6;
        break;
      default:
        idx = 3;
    }
    return Image.asset(
      'timecontrol/$idx.png',
      width: 42,
      height: 42,
      errorBuilder: (_, _, _) => _lightningIcon(),
    );
  }

  String _timeLabel(String control) {
    switch (control) {
      case 'Rapid':
        return '10min';
      case 'Chill':
        return '60s/move';
      case 'Blitz':
        return '5min + 3sec';
      case 'Tempo':
        return '20s/move';
      case 'Turbo':
        return '3min';
      case 'Bullet':
        return '2min + 1sec';
      default:
        return '5min + 3sec';
    }
  }

  Widget _findOpponentButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8C00).withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _startSearch,
            borderRadius: BorderRadius.circular(28),
            // Cropped opponent.png - no extra white space, tight fit
            child: Image.asset(
              'assets/images/home/opponent.png',
              width: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFFF8C00), width: 3),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Knight character cropped to actual part (72x75, removed 25px extra speed lines on right)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/images/home/knight_character.png',
                        width: 52,
                        height: 42,
                        fit: BoxFit.cover,
                        alignment: Alignment.centerLeft,
                        errorBuilder: (_, _, _) => const Text('🏃', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'FIND OPPONENT',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFFF8C00),
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFA62B), Color(0xFFFF8C00)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 19),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupChatPill() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            'assets/images/home/group.png',
            height: 52,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFD0DDE8), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/images/home/people.png',
                            width: 32,
                            height: 28,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(Icons.groups, color: Color(0xFF0B63CE), size: 24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Group Chat',
                          style: TextStyle(
                            color: Color(0xFF0F2A5A),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEAF2FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF0B63CE), size: 22),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomNavigation() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          height: 62,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE8EEF5), width: 1)),
          ),
          child: Row(
            children: [
              _navItem(0, Icons.videogame_asset, 'Play'),
              _navItem(1, Icons.group, 'Friends'),
              _navItem(2, Icons.emoji_events, 'Rankings'),
              _navItem(3, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData fallbackIcon, String label) {
    final selected = _tab == index;
    final activePath = 'assets/navbar/active/${index + 1}.png';
    final inactivePath = 'assets/navbar/inactive/${index + 1}.png';
    final imagePath = selected ? activePath : inactivePath;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tab = index),
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Image.asset(
            imagePath,
            height: 48,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Image.asset(
              'navbar/${selected ? "active" : "inactive"}/${index + 1}.png',
              height: 48,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    fallbackIcon,
                    size: 24,
                    color: selected ? const Color(0xFF0B63CE) : const Color(0xFF8A9BB0),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? const Color(0xFF0B63CE) : const Color(0xFF667085),
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

  Future<void> _pickTimeControl() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _TimeControlSheet(selected: _timeControl),
    );
    if (!mounted || selected == null) return;
    setState(() => _timeControl = selected);
  }

  void _startSearch() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => SearchingScreen(
          profileRepo: profileRepo,
          timeControl: _timeControl,
        ),
      ),
    );
  }

  void _customizeProfile() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => AnimatedBuilder(
        animation: profileRepo,
        builder: (context, child) {
          final profile = profileRepo.profile;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Customize',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    BotAvatar(seed: profile.avatarSeed, size: 62),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          Text('${profile.rating} rating', style: const TextStyle(color: Color(0xFF6B7FA3))),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: profileRepo.rerollAvatar,
                      tooltip: 'Generate new avatar',
                      icon: const Icon(Icons.refresh),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _editName();
                        });
                      },
                      tooltip: 'Edit name',
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Board theme', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                for (final theme in boardThemes)
                  InkWell(
                    onTap: () => profileRepo.setBoardTheme(theme.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                      decoration: BoxDecoration(
                        color: profile.boardThemeId == theme.id ? const Color(0xFFEAF2FF) : const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: profile.boardThemeId == theme.id ? const Color(0xFF0B63CE) : const Color(0xFFE0E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 42,
                            height: 28,
                            child: GridView.count(
                              crossAxisCount: 2,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              children: [
                                for (var i = 0; i < 4; i++)
                                  ColoredBox(color: i.isEven ? theme.lightSquare : theme.darkSquare),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Text(theme.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                          if (profile.boardThemeId == theme.id)
                            const Icon(Icons.check_circle, color: Color(0xFF0B63CE), size: 20),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                const Text('Piece style', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                for (final style in [('modern', 'Modern pieces', 'New pieces'), ('classic', 'Classic pieces', 'Original set')])
                  InkWell(
                    onTap: () => profileRepo.setPieceStyle(style.$1),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                        color: profile.pieceStyle == style.$1 ? const Color(0xFFEAF2FF) : const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: profile.pieceStyle == style.$1 ? const Color(0xFF0B63CE) : const Color(0xFFE0E8F0),
                        ),
                      ),
                      child: Row(
                        children: [
                          ChessPieceImage(value: 100, style: style.$1, size: 38),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(style.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(style.$3, style: const TextStyle(color: Color(0xFF6B7FA3), fontSize: 12)),
                              ],
                            ),
                          ),
                          if (profile.pieceStyle == style.$1)
                            const Icon(Icons.check_circle, color: Color(0xFF0B63CE), size: 20),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showProfileInfo(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(color: Color(0xFF6B7FA3), height: 1.4),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0B63CE)),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _comingSoon() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Coming soon',
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w900),
        ),
        content: const Text(
          'Offline arena play is ready now — this arrives with online multiplayer.',
          style: TextStyle(color: Color(0xFF667085)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _editName() {
    final controller = TextEditingController(text: profileRepo.profile.name);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Your arena name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 16,
          decoration: const InputDecoration(hintText: 'e.g. KnightRider'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              profileRepo.updateName(controller.text);
              Navigator.of(dialogContext).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0B63CE)),
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  /// Tapping the avatar or name: choose to edit the name or reroll avatar.
  void _showEditProfile() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: Color(0xFF0B63CE)),
                title: const Text('Edit name'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _editName();
                },
              ),
              ListTile(
                leading: const Icon(Icons.face_retouching_natural, color: Color(0xFF0B63CE)),
                title: const Text('Change avatar'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  profileRepo.rerollAvatar();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Stats button: recent games, accuracy and key numbers in one sheet.
  void _showStatsSheet() {
    final p = profileRepo.profile;
    final accuracy = profileRepo.averageAccuracy;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Your stats',
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(height: 14),
              if (profileRepo.ratingHistory().length >= 2)
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F8FE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rating — last 20 games',
                        style: TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: CustomPaint(
                          size: const Size(double.infinity, 60),
                          painter: _RatingSparkPainter(
                            profileRepo.ratingHistory(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _profileStat('${p.gamesPlayed}', 'Games'),
                    _profileStat('${p.wins}', 'Wins'),
                    _profileStat('${p.draws}', 'Draws'),
                    _profileStat('${p.losses}', 'Losses'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F8FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _profileStat(accuracy == null ? '—' : '${accuracy.round()}%', 'Accuracy'),
                    _profileStat('${(p.winRate * 100).round()}%', 'Win rate'),
                    _profileStat('${p.bestWinStreak}', 'Best wins'),
                    _profileStat('${profileRepo.activeDayStreak}', 'Streak'),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Recent games',
                style: TextStyle(color: Color(0xFF0F172A), fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _recentGames(),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset profile?'),
        content: const Text('This wipes your name, rating and history back to a fresh 1000.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              profileRepo.resetAll();
              Navigator.of(dialogContext).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _tabPage({required String title, required Widget child}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 28),
          child,
        ],
      ),
    );
  }

  Widget _profileMenuItem({
    required String emoji,
    required String title,
    required String detail,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            SizedBox(width: 34, child: Text(emoji, style: const TextStyle(fontSize: 22))),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF6B7FA3), fontSize: 11),
                  ),
                ],
              ),
            ),
            const Text('›', style: TextStyle(color: Color(0xFF6B7FA3), fontSize: 24)),
          ],
        ),
      ),
    );
  }

  Widget _profileStat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.w900),
        ),
        Text(label, style: const TextStyle(color: Color(0xFF6B7FA3), fontSize: 11)),
      ],
    );
  }

  Widget _recentGames() {
    final games = profileRepo.recentGames(limit: 5);
    if (games.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
            ),
          ],
        ),
        child: const Text(
          'No games yet. Find an opponent and play your first battle!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF6B7FA3)),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < games.length; i++) ...[
            _gameTile(games[i]),
            if (i != games.length - 1) const Divider(height: 1, color: Color(0xFFE0E8F0)),
          ],
        ],
      ),
    );
  }

  Widget _gameTile(GameRecord game) {
    final color = game.eloDelta > 0
        ? const Color(0xFF16A34A)
        : game.eloDelta < 0
            ? const Color(0xFFDC2626)
            : const Color(0xFF6B7FA3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              game.result.short,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 17),
            ),
          ),
          CountryFlag(isoCode: game.botIso, width: 23, height: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${game.botName} · ${game.moves} moves',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            EloService.formatDelta(game.eloDelta),
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _friendsPage() {
    return _tabPage(
      title: 'Friends',
      child: Column(
        children: [
          const SizedBox(height: 36),
          Container(
            width: 108,
            height: 108,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD0DDE8)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Text('⚔️', style: TextStyle(fontSize: 58)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Play with friends',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a free account to find friends and challenge them to games.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7FA3), height: 1.4),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _comingSoon,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0B63CE),
              ),
              child: const Text('Create free account'),
            ),
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _comingSoon,
              child: const Text('Login'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rankingsPage() {
    const globalLeaders = [
      ('PH', 'toto pogi', 22478),
      ('NL', 'lionsgame', 17160),
      ('DE', 'DJAWM', 15425),
      ('IN', 'Bhola 12+Age', 10846),
      ('IN', 'ilaya raja g', 10673),
      ('ID', 'uciliano', 10032),
      ('MX', 'marcoarango', 8600),
      ('PK', 'Muhammad Riyas', 8500),
      ('ID', 'JancoxJaran', 7771),
      ('RU', 'I WILL KILL U', 7065),
      ('ES', 'Tachi Nerja', 7060),
    ];
    const localLeaders = [
      ('PK', 'KarachiKnight', 2840),
      ('PK', 'LahoreLion', 2716),
      ('PK', 'SindhStrategist', 2635),
      ('PK', 'Queen Gambit PK', 2511),
      ('PK', 'RookRider', 2448),
      ('PK', 'Islamabad Chess', 2392),
      ('PK', 'The Green Bishop', 2320),
      ('PK', 'Peshawar Pawn', 2277),
      ('PK', 'Checkmate Club', 2194),
      ('PK', 'Arena Falcon', 2110),
      ('PK', 'Rapid Raja', 2072),
    ];
    final leaders = _globalRankings ? globalLeaders : localLeaders;
    return CustomScrollView(
      key: const PageStorageKey<String>('rankings-page'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Rankings',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _ScopeToggle(
                  global: _globalRankings,
                  onChanged: (global) {
                    setState(() => _globalRankings = global);
                  },
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(child: _podium(leaders.take(3).toList())),
        SliverList.builder(
          itemCount: leaders.length - 3,
          itemBuilder: (context, index) {
            final rank = index + 4;
            final player = leaders[index + 3];
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE0E8F0)),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 45,
                    child: Text(
                      '#$rank',
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  CountryFlag(isoCode: player.$1, width: 34, height: 23),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      player.$2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Text('▥', style: TextStyle(color: Color(0xFFE54722), fontSize: 25)),
                  const SizedBox(width: 9),
                  Text(
                    '${player.$3}',
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
    );
  }

  Widget _podium(List<(String, String, int)> leaders) {
    final order = [leaders[1], leaders[0], leaders[2]];
    final ranks = [2, 1, 3];
    final heights = [84.0, 104.0, 72.0];
    final colors = [const Color(0xFFC7CDD2), const Color(0xFFE2C438), const Color(0xFFC98235)];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < order.length; i++)
            Expanded(
              child: Column(
                children: [
                  BotAvatar(seed: 'rank-${order[i].$2}', size: i == 1 ? 66 : 56),
                  const SizedBox(height: 6),
                  Text(
                    order[i].$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '(${order[i].$3})',
                    style: const TextStyle(color: Color(0xFF6B7FA3), fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: heights[i],
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors[i],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Text(
                      '#${ranks[i]}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _profilePage() {
    return _tabPage(
      title: 'Profile',
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                _profileMenuItem(
                  emoji: '🎨',
                  title: 'Customize',
                  detail: 'Avatar, name, board and pieces',
                  onTap: _customizeProfile,
                ),
                const Divider(height: 1, color: Color(0xFFE0E8F0)),
                _profileMenuItem(
                  emoji: '👤',
                  title: 'Account',
                  detail: 'Offline arena profile',
                  onTap: () => _showProfileInfo(
                    'Account',
                    'Your profile is stored locally. Online account linking is planned for multiplayer.',
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE0E8F0)),
                _profileMenuItem(
                  emoji: '🛡️',
                  title: 'Privacy',
                  detail: 'Your game data stays on this device',
                  onTap: () => _showProfileInfo(
                    'Privacy',
                    'Chess Arena v1 stores your rating, history and preferences on this device.',
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE0E8F0)),
                _profileMenuItem(
                  emoji: '📖',
                  title: 'Rules',
                  detail: 'Fair play and community rules',
                  onTap: () => _showProfileInfo(
                    'Arena rules',
                    'Play fairly, be respectful in chat, and finish every game you can. Leaving an active game counts as a resignation.',
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE0E8F0)),
                _profileMenuItem(
                  emoji: '🗳️',
                  title: 'Community Poll',
                  detail: 'Help shape the next release',
                  onTap: _comingSoon,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFA62B), Color(0xFFFF8C00)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                Text(
                  'Arena profile • Free offline play',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'Adaptive opponents, ratings and chat included',
                  style: TextStyle(color: Color(0xFFFFE4BD), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _confirmReset,
              child: const Text('Reset offline profile'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a child in a rounded-rect halo whose bright orange spots revolve
/// around the border, drawing the eye to the Find Opponent button.
class _RotatingRay extends StatefulWidget {
  final Widget child;

  const _RotatingRay({required this.child});

  @override
  State<_RotatingRay> createState() => _RotatingRayState();
}

class _RotatingRayState extends State<_RotatingRay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (_, _) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _RayPainter(_spin.value * 2 * pi)),
          ),
          Padding(padding: const EdgeInsets.all(5), child: widget.child),
        ],
      ),
    );
  }
}

class _RayPainter extends CustomPainter {
  final double angle;

  const _RayPainter(this.angle);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..shader = SweepGradient(
        colors: const [
          Color(0x00FF8C00),
          Color(0xFFFFB341),
          Color(0x00FF8C00),
          Color(0xFFFF8C00),
          Color(0x00FF8C00),
        ],
        stops: const [0.0, 0.15, 0.5, 0.65, 1.0],
        transform: GradientRotation(angle),
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(30)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RayPainter oldDelegate) =>
      oldDelegate.angle != angle;
}

class _StatsChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final barPaint = Paint()..style = PaintingStyle.fill;
    final bars = [0.4, 0.7, 0.5, 1.0];
    final colors = [
      const Color(0xFF93C5FD),
      const Color(0xFF60A5FA),
      const Color(0xFF93C5FD),
      const Color(0xFF1E5BCE),
    ];
    final barWidth = size.width / 7;
    final gap = barWidth * 0.5;
    for (var i = 0; i < bars.length; i++) {
      barPaint.color = colors[i];
      final h = size.height * bars[i];
      final x = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, size.height - h, barWidth, h),
          const Radius.circular(2),
        ),
        barPaint,
      );
    }
    final arrowPaint = Paint()
      ..color = const Color(0xFF1E5BCE)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.55, size.height * 0.15)
      ..lineTo(size.width * 0.95, size.height * 0.05)
      ..lineTo(size.width * 0.95, size.height * 0.35);
    canvas.drawPath(path, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScopeToggle extends StatelessWidget {
  final bool global;
  final ValueChanged<bool> onChanged;

  const _ScopeToggle({required this.global, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFF6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _option('🌍', true),
          _option('🇵🇰', false),
        ],
      ),
    );
  }

  Widget _option(String label, bool value) {
    final selected = global == value;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 56,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: selected
            ? BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFA62B), Color(0xFFFF8C00)],
                ),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}

class _TimeControlSheet extends StatefulWidget {
  final String selected;

  const _TimeControlSheet({required this.selected});

  @override
  State<_TimeControlSheet> createState() => _TimeControlSheetState();
}

class _TimeControlSheetState extends State<_TimeControlSheet> {
  late String _selected;

  static const options = [
    ('timecontrol/1.png', 'Rapid', '10 min'),
    ('timecontrol/2.png', 'Chill', '60 seconds/move'),
    ('timecontrol/3.png', 'Blitz', '5 min +3 seconds/move'),
    ('timecontrol/4.png', 'Tempo', '20 seconds/move'),
    ('timecontrol/5.png', 'Turbo', '3 min'),
    ('timecontrol/6.png', 'Bullet', '2 min +1 second/move'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFD0DDE8),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Time controls',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Pick your pace — the bot adapts to every mode',
            style: TextStyle(color: Color(0xFF6B7FA3), fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE0E8F0)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  InkWell(
                    // Selecting a mode applies it instantly and pops the
                    // sheet — no DONE tap needed.
                    onTap: () => Navigator.of(context).pop(options[i].$2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 46,
                            height: 38,
                            child: Image.asset(
                              options[i].$1,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(Icons.timer_outlined, size: 28),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  options[i].$2,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  options[i].$3,
                                  style: TextStyle(
                                    color: options[i].$2 == _selected
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF6B7FA3),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: options[i].$2 == _selected
                                  ? const Color(0xFFFF8C00)
                                  : Colors.transparent,
                              border: Border.all(
                                color: options[i].$2 == _selected
                                    ? const Color(0xFFFF8C00)
                                    : const Color(0xFFD0DDE8),
                                width: 2,
                              ),
                            ),
                            child: options[i].$2 == _selected
                                ? const Text('✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12))
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (i != options.length - 1)
                    const Divider(height: 1, color: Color(0xFFE0E8F0)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Tap a mode to apply it instantly.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF6B7FA3), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Sparkline of the last-20-games rating on the home rating card.
class _RatingSparkPainter extends CustomPainter {
  final List<int> history;

  _RatingSparkPainter(this.history);

  @override
  void paint(Canvas canvas, Size size) {
    if (history.length < 2) {
      final p = Paint()
        ..color = const Color(0xFFD0DDE8)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        p,
      );
      return;
    }
    final min = history.reduce((a, b) => a < b ? a : b);
    final max = history.reduce((a, b) => a > b ? a : b);
    final span = (max - min).clamp(1, 100000);
    final step = size.width / (history.length - 1);

    final path = Path();
    for (var i = 0; i < history.length; i++) {
      final x = i * step;
      final y = size.height -
          5 -
          ((history[i] - min) / span) * (size.height - 10);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path()
      ..addPath(path, Offset.zero)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()..color = const Color(0x220B63CE),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF0B63CE)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
    // Latest point dot.
    final lx = (history.length - 1) * step;
    final ly = size.height -
        5 -
        ((history.last - min) / span) * (size.height - 10);
    canvas.drawCircle(Offset(lx, ly), 3, Paint()..color = const Color(0xFF0B63CE));
  }

  @override
  bool shouldRepaint(_RatingSparkPainter old) => old.history != history;
}
