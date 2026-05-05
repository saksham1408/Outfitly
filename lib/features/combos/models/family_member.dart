import 'package:flutter/foundation.dart';

/// Roles in a family / couple roster.
///
/// Two role flavours coexist:
///   * **Familial** — grandfather / grandmother / father / mother /
///     son / daughter. Used by the family roster builder where the
///     framing is "who's in this household".
///   * **Generic adult** — male / female. Used by the Couple
///     shortcut where the framing is "two adults in matching looks"
///     — agnostic to whether they're parents, dating, engaged.
///
/// Combo templates and the garment catalog declare prices /
/// options for both flavours so either branch of the wizard
/// reaches the Lookbook with non-empty results.
enum FamilyRole {
  grandfather,
  grandmother,
  father,
  mother,
  son,
  daughter,
  /// Used by the Couple shortcut — "Male" is the adult-male
  /// without the "father" framing.
  male,
  /// Couple shortcut counterpart of [male].
  female;

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
      case FamilyRole.male:
        return 'Male';
      case FamilyRole.female:
        return 'Female';
    }
  }

  /// Whether this role represents a child. Drives the kid-card
  /// quantity selector — adults are toggled (1 or 0), kids get
  /// a +/- counter. Male / female are explicitly adult.
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

/// Predefined rosters used by the Couple-flavour shortcut on the
/// combo selection screen. Uses the generic [FamilyRole.male] /
/// [FamilyRole.female] roles rather than father/mother so the
/// labels read "Male" / "Female" throughout the wizard — the
/// couple flow doesn't assume the two adults are parents. Family
/// flow builds its roster dynamically via the FamilyBuilderScreen.
class CoupleRoster {
  static const List<FamilyMember> defaultRoster = [
    FamilyMember(role: FamilyRole.male),
    FamilyMember(role: FamilyRole.female),
  ];
}
