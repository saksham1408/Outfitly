import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'core/network/supabase_client.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/wardrobe_calendar/data/notification_service.dart';

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

  // Opt-in auto-test for the notification pipeline. Enabled with
  //   flutter run --dart-define=NOTIF_AUTO_TEST=true
  // so normal debug runs don't spam a banner. When set, we warm up the
  // NotificationService (forcing the iOS permission prompt early) and
  // schedule a test reminder 20 seconds from boot — plenty of time to
  // tap "Allow" and background the app before the banner fires.
  const autoTest = bool.fromEnvironment('NOTIF_AUTO_TEST', defaultValue: false);
  if (autoTest) {
    await NotificationService.instance.init();
    await NotificationService.instance.scheduleTestReminder(delaySeconds: 20);
    debugPrint('NOTIF_AUTO_TEST: test reminder scheduled for +20s');
  }

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
