import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';

/// Initializes and exposes the Supabase singleton.
abstract final class AppSupabase {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }
}
