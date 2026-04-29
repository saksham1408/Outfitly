import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'country_currency_map.dart';
import 'fx_rate_service.dart';

/// App-wide currency localization.
///
/// Single static entry point: callers pass an INR-denominated amount
/// (the catalog stores everything in rupees) and get back a
/// locale-formatted string. The active country drives both the target
/// currency and the digit-grouping/decimal conventions.
///
/// Three behaviour modes, mirroring the master spec:
///
///   * **Condition A — India**: returns the INR amount with the
///     `en_IN` lakh-grouped format (e.g. `₹1,50,000`). No FX call;
///     no rounding artefacts.
///   * **Condition B — Rest of world**: multiplies by the cached FX
///     rate and formats with the country's locale (e.g. `£1,800`,
///     `€2,100`, `¥300,000`).
///   * **Condition C — Fallback**: country undetectable, currency
///     unsupported, or FX rates haven't loaded → USD with `en_US`
///     formatting.
///
/// **Source-of-truth precedence** (highest wins):
///
///   1. Explicit override stored in SharedPreferences (the user's
///      choice during register, or a profile change later). This is
///      what makes "I picked France at signup" stick across launches.
///   2. Device locale (PlatformDispatcher → Platform.localeName).
///   3. USD fallback.
///
/// Designed as a [ChangeNotifier] so widgets can `AnimatedBuilder` on
/// it and rebuild the moment FX rates finish loading or the user
/// changes country. For most calls the static [Money.format] is enough.
class Money extends ChangeNotifier {
  Money._();
  static final Money instance = Money._();

  /// Persistence key for the user's explicit country override. Bumped
  /// only if the storage shape ever changes.
  static const String _kOverrideKey = 'money_country_override_v1';

  CurrencyInfo _currency = kIndiaCurrency;
  bool _initialized = false;
  String? _overrideCountry; // ISO-2, set by setOverrideCountry()

  /// Currently active currency. Reads as [kIndiaCurrency] before
  /// [init] runs — that's the right default since the catalog itself
  /// is INR-denominated and India is launch market #1.
  CurrencyInfo get currency => _currency;

  /// The user's explicit country choice, if any. Useful for the
  /// register screen to pre-select the picker on a re-mount.
  String? get overrideCountry => _overrideCountry;

  /// True once locale detection AND a first FX fetch attempt have
  /// completed (whether or not the network call succeeded). UI can
  /// branch on this to show e.g. an "approx." disclaimer for the
  /// converted price.
  bool get isReady => _initialized;

  /// One-time boot. Resolves the active country (override → device
  /// locale → USD fallback), picks the matching [CurrencyInfo], and
  /// kicks off the FX rate refresh. Awaiting this is *optional* —
  /// the app boots fine without — but doing so means the first paint
  /// already has correct prices for non-Indian users.
  ///
  /// [overrideCountry] is mostly for testing; in production the saved
  /// override is read from SharedPreferences.
  Future<void> init({String? overrideCountry}) async {
    // Layer 1: persisted user choice. Sub-millisecond on a warm app,
    // ~5ms on a cold launch — fast enough to not delay first paint.
    final saved = await _readSavedOverride();
    _overrideCountry = overrideCountry ?? saved;

    final country = _overrideCountry ?? _detectCountry();
    _currency = currencyForCountry(country);

    // No need to fetch FX if we're already in INR-land — it's the
    // base currency, conversion is a no-op.
    if (_currency.code != 'INR') {
      await FxRateService.instance.ensureLoaded();
    }

    _initialized = true;
    notifyListeners();
  }

  /// Apply a user-chosen country and persist it. Triggers an FX fetch
  /// if needed and broadcasts a [notifyListeners] so prices repaint
  /// across the app instantly.
  ///
  /// Pass `null` to clear the override and fall back to device locale.
  Future<void> setOverrideCountry(String? countryCode) async {
    final normalised = countryCode?.trim().toUpperCase();
    _overrideCountry = (normalised == null || normalised.isEmpty)
        ? null
        : normalised;
    _currency = currencyForCountry(_overrideCountry ?? _detectCountry());

    // Persist *before* notifying so a listener that re-reads
    // SharedPreferences sees the new value already.
    await _writeSavedOverride(_overrideCountry);

    if (_currency.code != 'INR') {
      // Don't await — UI should repaint with last-known FX rates
      // immediately; a fresh fetch can land in a frame or two.
      // ignore: unawaited_futures
      FxRateService.instance.ensureLoaded().then((_) => notifyListeners());
    }

    notifyListeners();
  }

  /// Format an INR-denominated [amount] for display. Returns a string
  /// like `₹1,50,000` (India), `£18.00` (UK), `¥3,000` (JP),
  /// `$25.00` (fallback).
  ///
  /// Safe to call before [init] — falls back to printing the raw INR
  /// value with the rupee symbol if rates aren't loaded yet, which
  /// matches the catalog's existing behaviour.
  String format(double amount) {
    final c = _currency;
    final converted = c.code == 'INR'
        ? amount
        : amount * FxRateService.instance.rate(c.code);

    return _buildFormatter(c).format(converted);
  }

  /// Static convenience so widgets that don't subscribe to changes
  /// (most of them — prices don't animate mid-screen) can read the
  /// current formatted price without grabbing the singleton.
  static String formatStatic(double inrAmount) =>
      instance.format(inrAmount);

  // ── internals ─────────────────────────────────────────────────

  Future<String?> _readSavedOverride() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_kOverrideKey);
      if (v == null || v.trim().isEmpty) return null;
      return v.trim().toUpperCase();
    } catch (e) {
      debugPrint('Money: failed to read override ($e) — ignoring.');
      return null;
    }
  }

  Future<void> _writeSavedOverride(String? code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (code == null) {
        await prefs.remove(_kOverrideKey);
      } else {
        await prefs.setString(_kOverrideKey, code);
      }
    } catch (e) {
      debugPrint('Money: failed to persist override ($e) — ignoring.');
    }
  }

  /// Determine the user's country code. We prefer the platform
  /// dispatcher's locale (no permission prompt, instant) over
  /// geolocation — for v1 that's plenty. Future iterations can fall
  /// through to an IP-based lookup or the user's profile address.
  String? _detectCountry() {
    try {
      // Flutter exposes the device locale via PlatformDispatcher; the
      // `countryCode` field is e.g. "IN" for an Indian-region device,
      // null on iOS Simulator default ("en") which is fine — we'll
      // fall through to USD.
      final locale = PlatformDispatcher.instance.locale;
      final fromLocale = locale.countryCode;
      if (fromLocale != null && fromLocale.isNotEmpty) return fromLocale;

      // Secondary: read the OS locale string. Returns "en_US",
      // "en_IN.UTF-8", etc. We split on `_` and `-` to be tolerant.
      if (!kIsWeb) {
        final raw = Platform.localeName; // e.g. "en_IN", "en_US.UTF-8"
        final cleaned = raw.split('.').first;
        final parts = cleaned.split(RegExp(r'[_-]'));
        if (parts.length > 1 && parts[1].isNotEmpty) return parts[1];
      }
    } catch (e) {
      debugPrint('Money: country detection failed ($e) — falling back.');
    }
    return null;
  }

  NumberFormat _buildFormatter(CurrencyInfo c) {
    return NumberFormat.currency(
      locale: c.locale,
      symbol: c.symbol,
      decimalDigits: c.decimalDigits,
    );
  }
}
