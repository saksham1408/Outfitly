import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'core/locale/money.dart';
import 'core/network/supabase_client.dart';
import 'core/push/push_notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/wardrobe_calendar/data/notification_service.dart';
import 'firebase_options.dart';

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

  // Firebase + push notifications. Wrapped in a try/catch because
  // builds without google-services.json / GoogleService-Info.plist
  // (e.g. fresh dev clones, CI smoke tests) would otherwise crash
  // here — and a missing Firebase config shouldn't block the rest
  // of the app from booting. PushNotificationService.initialize is
  // also defensive: it catches its own errors so the worst case
  // is "no marketing pushes today, app still works fine".
  try {
    // Pass explicit options from the FlutterFire-generated file so
    // initialization is platform-aware on iOS without falling back
    // to the GoogleService-Info.plist autodiscovery — keeps the
    // boot path identical across iOS, Android, and (future) web.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint(
      'Firebase: initializeApp failed — push notifications disabled '
      'until google-services.json / GoogleService-Info.plist is added '
      '($e)',
    );
  }
  unawaited(PushNotificationService.instance.initialize());

  // Currency localization. Fire-and-forget on purpose: the catalog is
  // INR-denominated, so even if the FX fetch hasn't finished by the
  // first paint we'll just render in ₹ for a frame or two before
  // notifyListeners() repaints with the converted value. Awaiting here
  // would block boot on a slow network for no UX benefit.
  unawaited(Money.instance.init());

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
    // AnimatedBuilder over Money.instance ensures every price-displaying
    // widget rebuilds the moment FX rates resolve — without this, a UK
    // user would see ₹ prices for the whole session if Money.init()
    // hadn't completed before the first paint.
    return AnimatedBuilder(
      animation: Money.instance,
      builder: (context, _) => MaterialApp.router(
        title: 'VASTRAHUB',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: AppRouter.router,
      ),
    );
  }
}
