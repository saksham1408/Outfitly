import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny FX-rate fetcher around `open.er-api.com` (free, no key, returns
/// rates for ~161 currencies).
///
/// Why not a paid API: the price-display use-case is informational, not
/// transactional. We're not actually charging in the user's local
/// currency — payment still settles in INR — so a five-minute-stale
/// rate sourced from a free aggregator is fine. If we ever wire up
/// real multi-currency Stripe payments, swap this for `openexchangerates`
/// with a paid key and add a server-side rate-of-record column.
///
/// Caching:
///   * In-memory until [_kTtl] (6h) — covers a session.
///   * Persisted to [SharedPreferences] so cold launches in airplane
///     mode still render localized prices using the last-good rates.
///
/// Failure posture: every public method always resolves; the worst
/// case is the caller getting a rates map of `{'INR': 1.0}` and falling
/// back to base prices. Never throws into the UI.
class FxRateService {
  FxRateService._();
  static final FxRateService instance = FxRateService._();

  // open.er-api.com keys rates by quote currency, with our base (INR)
  // baked into the URL. Format:
  //   { "result": "success", "base_code": "INR",
  //     "rates": { "USD": 0.012, "EUR": 0.011, ... } }
  static const String _kEndpoint =
      'https://open.er-api.com/v6/latest/INR';

  static const Duration _kTtl = Duration(hours: 6);
  static const String _kCacheKey = 'fx_rates_inr_cache_v1';
  static const String _kCacheStampKey = 'fx_rates_inr_cache_stamp_v1';

  Map<String, double>? _ratesInMemory;
  DateTime? _fetchedAt;

  /// Ratio to multiply an INR amount by to get the [quoteCurrency]
  /// amount. Returns 1.0 if rates haven't loaded yet OR the requested
  /// currency isn't in the map — both safe degradations.
  double rate(String quoteCurrency) {
    final code = quoteCurrency.trim().toUpperCase();
    if (code == 'INR') return 1.0;
    final rates = _ratesInMemory;
    if (rates == null) return 1.0;
    return rates[code] ?? 1.0;
  }

  /// Truthy when we have a usable rates map in memory. The Money
  /// service uses this to decide whether to surface "≈" prefix on a
  /// converted price (visual hint that it's an approximation).
  bool get isReady => _ratesInMemory != null;

  /// Pull the latest rates. Cached path returns instantly; fresh fetch
  /// is bounded by the [networkTimeout]. Idempotent — calling twice in
  /// the TTL window is cheap.
  ///
  /// Order of operations:
  ///   1. If we already have a fresh in-memory copy, return.
  ///   2. Try to hydrate from SharedPreferences cache (sub-millisecond).
  ///   3. If still stale OR refresh==true, hit the network with a
  ///      timeout so a slow connection can't block the UI.
  ///   4. Persist whatever we got back to the cache.
  Future<void> ensureLoaded({
    bool refresh = false,
    Duration networkTimeout = const Duration(seconds: 4),
  }) async {
    if (!refresh && _hasFreshInMemoryCache()) return;

    // Layer 1: SharedPreferences cache. Fast enough that we never
    // skip it — even when the caller asks for a refresh, we still
    // hydrate first so the in-memory ratemap is non-null while the
    // network call is in flight.
    if (_ratesInMemory == null) {
      await _hydrateFromDisk();
    }

    if (!refresh && _hasFreshInMemoryCache()) return;

    // Layer 2: network. Catch + log everything — we never want to
    // throw out of this method and surprise the UI layer.
    try {
      final response = await http
          .get(Uri.parse(_kEndpoint))
          .timeout(networkTimeout);

      if (response.statusCode != 200) {
        debugPrint(
          'FxRateService: ${response.statusCode} from open.er-api — '
          'keeping previous cache.',
        );
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['result'] != 'success') {
        debugPrint(
          'FxRateService: API returned result=${body['result']} — '
          'keeping previous cache.',
        );
        return;
      }

      final rawRates = body['rates'] as Map<String, dynamic>?;
      if (rawRates == null) {
        debugPrint('FxRateService: no rates field — keeping previous cache.');
        return;
      }

      final parsed = <String, double>{};
      rawRates.forEach((key, value) {
        if (value is num) parsed[key] = value.toDouble();
      });

      _ratesInMemory = parsed;
      _fetchedAt = DateTime.now();
      await _persistToDisk(parsed, _fetchedAt!);
      debugPrint(
        'FxRateService: refreshed ${parsed.length} rates at $_fetchedAt.',
      );
    } catch (e) {
      debugPrint('FxRateService: refresh failed ($e) — keeping cache.');
    }
  }

  bool _hasFreshInMemoryCache() {
    final stamp = _fetchedAt;
    return _ratesInMemory != null &&
        stamp != null &&
        DateTime.now().difference(stamp) < _kTtl;
  }

  Future<void> _hydrateFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      final stampMs = prefs.getInt(_kCacheStampKey);
      if (raw == null || stampMs == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final parsed = <String, double>{};
      decoded.forEach((key, value) {
        if (value is num) parsed[key] = value.toDouble();
      });
      _ratesInMemory = parsed;
      _fetchedAt = DateTime.fromMillisecondsSinceEpoch(stampMs);
    } catch (e) {
      debugPrint('FxRateService: cache hydrate failed ($e) — ignoring.');
    }
  }

  Future<void> _persistToDisk(
    Map<String, double> rates,
    DateTime fetchedAt,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(rates));
      await prefs.setInt(_kCacheStampKey, fetchedAt.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('FxRateService: cache persist failed ($e) — ignoring.');
    }
  }
}
