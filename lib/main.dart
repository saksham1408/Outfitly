import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
