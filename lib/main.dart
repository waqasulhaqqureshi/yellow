import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/db/hive_setup.dart';
import 'core/theme/arena_theme.dart';
import 'features/game/presentation/screens/home_screen.dart';
import 'features/profile/data/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveSetup.init();
  final profileRepo = ProfileRepository();
  await profileRepo.load();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    DevicePreview(
      enabled: kIsWeb,
      builder: (context) => ChessArenaApp(profileRepo: profileRepo),
    ),
  );
}

class ChessArenaApp extends StatelessWidget {
  final ProfileRepository profileRepo;

  const ChessArenaApp({super.key, required this.profileRepo});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Arena',
      debugShowCheckedModeBanner: false,
      theme: ArenaTheme.dark(),
      locale: kIsWeb ? DevicePreview.locale(context) : null,
      builder: kIsWeb ? DevicePreview.appBuilder : null,
      home: HomeScreen(profileRepo: profileRepo),
    );
  }
}
