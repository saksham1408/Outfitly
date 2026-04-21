import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'core/network/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (GEMINI_API_KEY, etc.). Missing file is
  // non-fatal in debug so engineers without the shared .env can still
  // boot the app — downstream AI calls fall back gracefully.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('dotenv: could not load .env — falling back to defaults ($e)');
  }

  // Initialise the timezone database so `flutter_local_notifications`
  // can schedule events at a zoned local time (8 AM on the event day).
  // We hard-pin Asia/Kolkata since the app is launching India-first;
  // the catch keeps the app bootable if the zone db fails to load.
  try {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  } catch (e) {
    debugPrint('timezone: init failed, falling back to UTC ($e)');
  }

  await AppSupabase.init();
  runApp(const OutfitlyApp());
}

class OutfitlyApp extends StatelessWidget {
  const OutfitlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Outfitly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: AppRouter.router,
    );
  }
}
