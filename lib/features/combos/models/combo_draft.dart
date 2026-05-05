import 'package:flutter/foundation.dart';

import 'family_member.dart';

/// Immutable wizard state threaded through the combo
/// customization flow.
///
/// Each step in the wizard takes a [ComboDraft] via
/// `state.extra`, makes its choices, and pushes the next route
/// with a fresh copy via [copyWith]. By the time the customer
/// reaches the results screen the draft has the full picture:
///
///   * `roster`            — set on entry from
///                           ComboSelectionScreen / FamilyBuilderScreen.
///   * `garmentByRole`     — set on the garment screen. Keyed by
///                           [FamilyRole] so siblings of the same
///                           role share the same garment type
///                           (e.g. all sons wear Mini Kurta).
///   * `fabric`            — set on the fabric screen. One choice
///                           for the whole coordinated set.
///   * `sizeByMemberIndex` — set on the size screen. Keyed by the
///                           member's index in [expandedRoster]
///                           (each child gets a separate slot
///                           since siblings can be different
///                           ages).
@immutable
class ComboDraft {
  const ComboDraft({
    required this.roster,
    this.garmentByRole = const {},
    this.fabric,
    this.sizeByMemberIndex = const {},
  });

  final List<FamilyMember> roster;
  final Map<FamilyRole, String> garmentByRole;
  final String? fabric;
  final Map<int, String> sizeByMemberIndex;

  /// "Expanded" roster — kid roles with quantity > 1 produce
  /// multiple entries (one per child). Indexes here line up with
  /// the keys in [sizeByMemberIndex]. Adults always produce a
  /// single entry. Stable order so subsequent screens render the
  /// same list of cards.
  List<FamilyRole> get expandedRoster {
    final out = <FamilyRole>[];
    for (final member in roster) {
      for (var i = 0; i < member.quantity; i++) {
        out.add(member.role);
      }
    }
    return out;
  }

  /// True iff every required slot has been filled — gates the
  /// "Continue" button on each wizard step from advancing
  /// prematurely. Each step calls only the relevant getter
  /// (hasAllGarments, hasFabric, hasAllSizes).
  bool get hasAllGarments {
    for (final member in roster) {
      if (!garmentByRole.containsKey(member.role)) return false;
    }
    return true;
  }

  bool get hasFabric => fabric != null && fabric!.isNotEmpty;

  bool get hasAllSizes {
    final expected = expandedRoster.length;
    if (sizeByMemberIndex.length != expected) return false;
    for (var i = 0; i < expected; i++) {
      if (!sizeByMemberIndex.containsKey(i)) return false;
    }
    return true;
  }

  ComboDraft copyWith({
    List<FamilyMember>? roster,
    Map<FamilyRole, String>? garmentByRole,
    String? fabric,
    Map<int, String>? sizeByMemberIndex,
  }) {
    return ComboDraft(
      roster: roster ?? this.roster,
      garmentByRole: garmentByRole ?? this.garmentByRole,
      fabric: fabric ?? this.fabric,
      sizeByMemberIndex: sizeByMemberIndex ?? this.sizeByMemberIndex,
    );
  }
}
