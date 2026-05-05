import 'package:flutter/foundation.dart';

/// Roles in a family roster. The combo matching logic keys off this
/// enum to find the right per-person item from a [ComboSet] template
/// — e.g., "Father" maps to the kurta, "Daughter" maps to the
/// lehenga. Six roles cover the common Indian-family shape; the
/// catalog can be extended later (in-laws, siblings) without
/// changing the public surface here.
enum FamilyRole {
  grandfather,
  grandmother,
  father,
  mother,
  son,
  daughter;

  /// Display label used on the roster builder card and the
  /// per-member breakdown on the Lookbook results.
  String get label {
    switch (this) {
      case FamilyRole.grandfather:
        return 'Grandfather';
      case FamilyRole.grandmother:
        return 'Grandmother';
      case FamilyRole.father:
        return 'Father';
      case FamilyRole.mother:
        return 'Mother';
      case FamilyRole.son:
        return 'Son';
      case FamilyRole.daughter:
        return 'Daughter';
    }
  }

  /// Whether this role represents a child. Drives the kid-card
  /// quantity selector — adults are toggled (1 or 0), kids get
  /// a +/- counter.
  bool get isChild =>
      this == FamilyRole.son || this == FamilyRole.daughter;
}

/// One slot in a family roster. Adult roles always have
/// `quantity == 1` (you're either including the parent or you're
/// not). Children carry a real quantity since families commonly
/// have multiple kids of the same gender.
@immutable
class FamilyMember {
  const FamilyMember({
    required this.role,
    this.quantity = 1,
  });

  final FamilyRole role;
  final int quantity;

  FamilyMember copyWith({int? quantity}) =>
      FamilyMember(role: role, quantity: quantity ?? this.quantity);

  @override
  bool operator ==(Object other) =>
      other is FamilyMember &&
      other.role == role &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(role, quantity);
}

/// Two predefined rosters used by the Couple-flavour shortcut on
/// the combo selection screen. Family flow builds its roster
/// dynamically via the FamilyBuilderScreen.
class CoupleRoster {
  static const List<FamilyMember> defaultRoster = [
    FamilyMember(role: FamilyRole.father),
    FamilyMember(role: FamilyRole.mother),
  ];
}
