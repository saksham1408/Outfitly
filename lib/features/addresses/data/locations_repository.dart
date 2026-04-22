import 'package:flutter/foundation.dart';

import '../../../core/network/supabase_client.dart';
import '../domain/india_locations.dart' as seed;

/// Read-only source of truth for the State + City dropdowns on the
/// Add Address form.
///
/// Reads the `public.india_states` and `public.india_cities` reference
/// tables (migration `021_india_locations.sql`), which ship with a
/// Tier-1/2 seed and can be expanded by the catalog team at any time
/// without a client release. If the network call fails — or we're
/// running before the migration is applied — we fall back to the
/// bundled [seed] list so the form keeps working offline.
///
/// Shape: a single pair of ValueNotifiers (states + cities) so the
/// Add Address screen can wire its dropdowns with a plain
/// `ValueListenableBuilder` and refresh automatically once the
/// authoritative data arrives.
class LocationsRepository {
  LocationsRepository._()
      : states = ValueNotifier(List<String>.from(seed.indianStates)),
        citiesByState = ValueNotifier(
          Map<String, List<String>>.unmodifiable(seed.citiesByState),
        );

  static final LocationsRepository instance = LocationsRepository._();

  /// Alphabetical-ish (respects `display_order`) list of states + UTs.
  /// Seeded with the hardcoded [seed.indianStates] so the dropdown
  /// renders instantly; overwritten once Supabase responds.
  final ValueNotifier<List<String>> states;

  /// State-name → cities (including the "Other" escape-hatch row at
  /// the end). Same seed-then-remote pattern as [states].
  final ValueNotifier<Map<String, List<String>>> citiesByState;

  bool _remoteFetched = false;

  /// Idempotent. Fires a single parallel fetch for both reference
  /// tables and stitches cities onto states by id. On failure we keep
  /// the seed cache so the UI never blanks.
  Future<void> ensureLoaded() async {
    if (_remoteFetched) return;
    _remoteFetched = true;

    try {
      // Parallelize — these are small (~36 + ~250 rows) and they live
      // on the same origin, so Future.wait shaves a full round-trip
      // off the first paint.
      final results = await Future.wait<List<dynamic>>([
        AppSupabase.client
            .from('india_states')
            .select('id, name')
            .order('display_order')
            .order('name'),
        AppSupabase.client
            .from('india_cities')
            .select('state_id, name, is_other, display_order')
            .order('is_other')
            .order('display_order')
            .order('name'),
      ]);

      final stateRows =
          (results[0]).cast<Map<String, dynamic>>();
      final cityRows =
          (results[1]).cast<Map<String, dynamic>>();

      if (stateRows.isEmpty) {
        // Migration not yet applied — keep the seed.
        return;
      }

      final stateIdToName = <String, String>{};
      final stateList = <String>[];
      for (final r in stateRows) {
        final id = r['id'] as String?;
        final name = r['name'] as String?;
        if (id == null || name == null) continue;
        stateIdToName[id] = name;
        stateList.add(name);
      }

      final cityMap = <String, List<String>>{};
      for (final r in cityRows) {
        final sid = r['state_id'] as String?;
        final cname = r['name'] as String?;
        if (sid == null || cname == null) continue;
        final sname = stateIdToName[sid];
        if (sname == null) continue;
        cityMap.putIfAbsent(sname, () => <String>[]).add(cname);
      }

      // Only publish if we actually got meaningful data — otherwise
      // the seed fallback already covers the UI.
      states.value = stateList;
      citiesByState.value = Map<String, List<String>>.unmodifiable(cityMap);
    } catch (e, st) {
      debugPrint('LocationsRepository.ensureLoaded failed — $e\n$st');
      // Deliberately swallow; the seed cache already populated the
      // notifiers in the constructor.
    }
  }

  /// Cities for a given state, preferring the (possibly remote) cache
  /// and falling back to the bundled seed. Used by the Add Address
  /// screen's City dropdown.
  List<String> citiesFor(String state) {
    final cached = citiesByState.value[state];
    if (cached != null && cached.isNotEmpty) return cached;
    return seed.citiesFor(state);
  }
}
