import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/supabase_client.dart';
import '../../../core/push/device_token_service.dart';

class AuthService {
  final SupabaseClient _client = AppSupabase.client;
  final DeviceTokenService _deviceTokens = DeviceTokenService();

  // ── Streams & State ──

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;
  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // ── Email + Password Auth ──

  /// Register a new user with email and password.
  /// Stores profile info in user metadata so it persists even before email confirm.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
    String? phone,
    String? gender,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (gender != null) 'gender': gender,
      },
    );
  }

  /// Sign in with email and password.
  ///
  /// On success we fire-and-forget a push-token register — the call
  /// is safe to run before the FCM integration lands because the
  /// scaffold stub no-ops cleanly. When FCM is wired up, moving this
  /// call is the only change needed here.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user != null) {
      unawaited(_deviceTokens.registerCurrent());
    }
    return response;
  }

  /// Send a password reset email.
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ── Email OTP Auth (fallback) ──

  /// Send OTP to email address.
  Future<void> sendOtp(String email) async {
    await _client.auth.signInWithOtp(email: email);
  }

  /// Verify the OTP token.
  Future<AuthResponse> verifyOtp(String email, String token) async {
    return await _client.auth.verifyOTP(
      email: email,
      token: token,
      type: OtpType.email,
    );
  }

  // ── Profile Management ──

  /// Save or update the user's profile data in the profiles table.
  /// Accepts an explicit [userId] for cases where currentUser may be null
  /// (e.g. when email confirmation is required after signup).
  Future<void> upsertProfile({
    required String fullName,
    required String phone,
    required String email,
    String? gender,
    String? location,
    List<String>? preferredStyle,
    String? initialInterest,
    String? userId,
  }) async {
    final id = userId ?? currentUser?.id;
    if (id == null) return;

    await _client.from('profiles').upsert({
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      if (gender != null) 'gender': gender,
      if (location != null) 'location': location,
      if (preferredStyle != null) 'preferred_style': preferredStyle,
      if (initialInterest != null) 'initial_interest': initialInterest,
    });
  }

  /// Check if onboarding (style quiz) is complete.
  Future<bool> isOnboardingComplete() async {
    final user = currentUser;
    if (user == null) return false;

    final data = await _client
        .from('profiles')
        .select('onboarding_complete')
        .eq('id', user.id)
        .maybeSingle();

    return data?['onboarding_complete'] == true;
  }

  // ── Sign Out ──

  Future<void> signOut() async {
    // Drop our push token first so this device doesn't keep
    // receiving pushes for the account we're leaving. Awaited
    // because we want it to finish before the session clears —
    // once the auth uid flips to null, the RLS policy on
    // device_tokens.delete would reject the request.
    await _deviceTokens.unregisterCurrent();
    await _client.auth.signOut();
  }
}
