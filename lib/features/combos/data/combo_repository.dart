import '../models/combo_set.dart';
import '../models/family_member.dart';

/// Returns coordinated outfit sets for a given family roster.
///
/// MVP behaviour: client-side mocked templates. Each
/// [_ComboTemplate] declares a per-role price + product name,
/// plus the visual identity (palette colour, hero image,
/// tagline). For a given roster we instantiate the template by
/// looking up each member's role and stamping out a [ComboItem]
/// per person — kids with quantity > 1 produce N duplicate
/// items so the per-member breakdown reads e.g. "Son #1:
/// ₹1,200, Son #2: ₹1,200".
///
/// Future iteration: pull templates from a Postgres `combo_sets`
/// table managed by the merchandising team via Directus, with
/// price overrides per region + Realtime updates so a new
/// festive set appears on the dashboard the moment it's
/// published.
class ComboRepository {
  ComboRepository._();
  static final ComboRepository instance = ComboRepository._();

  /// Mocked-but-deterministic combo lookup. Returns every
  /// template that has at least one item matching at least one
  /// member of the [roster]. Empty rosters return empty.
  Future<List<ComboSet>> fetchMatchingCombos(
    List<FamilyMember> roster,
  ) async {
    if (roster.isEmpty) return const [];

    // Tiny artificial latency so the loading state on the
    // results screen doesn't feel like a bug — also gives the
    // Lookbook hero card a moment to fade in.
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final results = <ComboSet>[];
    for (final template in _templates) {
      final items = <ComboItem>[];
      for (final member in roster) {
        final spec = template.priceByRole[member.role];
        if (spec == null) continue;
        for (var i = 0; i < member.quantity; i++) {
          items.add(
            ComboItem(
              role: member.role,
              productName: spec.productName,
              price: spec.price,
            ),
          );
        }
      }
      // Skip templates that don't match any roster member —
      // showing a "set" with zero items would feel broken.
      if (items.isEmpty) continue;

      results.add(
        ComboSet(
          id: '${template.id}-${_rosterFingerprint(roster)}',
          name: template.name,
          tagline: template.tagline,
          items: items,
          paletteColor: template.paletteColor,
          discountPercent: template.discountPercent,
        ),
      );
    }

    return results;
  }

  /// Stable fingerprint of a roster — used as a suffix on the
  /// generated combo id so two browse sessions with the same
  /// roster produce the same id and any "favourited" state
  /// rehydrates cleanly.
  String _rosterFingerprint(List<FamilyMember> roster) {
    final sorted = [...roster]..sort((a, b) => a.role.name.compareTo(b.role.name));
    return sorted.map((m) => '${m.role.name}${m.quantity}').join('-');
  }
}

// ────────────────────────────────────────────────────────────
// Template definitions
// ────────────────────────────────────────────────────────────
//
// Each entry is a "look" — a coordinated palette + style. The
// per-role map declares what every family-member type wears in
// that look. Roles missing from the map are simply skipped at
// instantiation time, so a couples-only roster against the
// "Royal Blue Diwali" template just produces the father +
// mother items.

class _ComboTemplate {
  const _ComboTemplate({
    required this.id,
    required this.name,
    required this.tagline,
    required this.paletteColor,
    required this.priceByRole,
    this.discountPercent = 10.0,
  });

  final String id;
  final String name;
  final String tagline;
  final int paletteColor;
  final double discountPercent;
  final Map<FamilyRole, _ItemSpec> priceByRole;
}

class _ItemSpec {
  const _ItemSpec(this.productName, this.price);
  final String productName;
  final double price;
}

const List<_ComboTemplate> _templates = [
  _ComboTemplate(
    id: 'royal-blue-diwali',
    name: 'Royal Blue Diwali Set',
    tagline: 'Deep indigo silks with gold zari trim — the Diwali night look.',
    paletteColor: 0xFF1E3A8A,
    discountPercent: 10.0,
    priceByRole: {
      FamilyRole.grandfather: _ItemSpec('Indigo Bandhgala Sherwani', 7500),
      FamilyRole.grandmother: _ItemSpec('Navy Brocade Saree', 6500),
      FamilyRole.father: _ItemSpec('Royal Blue Silk Kurta', 4500),
      FamilyRole.mother: _ItemSpec('Cobalt Silk Saree', 5500),
      FamilyRole.son: _ItemSpec('Mini Royal Blue Kurta', 1800),
      FamilyRole.daughter: _ItemSpec('Royal Blue Lehenga', 2200),
      // Couple-flow: same garments as the parental roles, named
      // generically so the Lookbook breakdown reads "Male: Royal
      // Blue Silk Kurta" instead of "Father: …".
      FamilyRole.male: _ItemSpec('Royal Blue Silk Kurta', 4500),
      FamilyRole.female: _ItemSpec('Cobalt Silk Saree', 5500),
    },
  ),
  _ComboTemplate(
    id: 'pastel-wedding',
    name: 'Pastel Wedding Collection',
    tagline: 'Soft sage and blush — for the engagement and the haldi.',
    paletteColor: 0xFFB6CDB1,
    discountPercent: 12.0,
    priceByRole: {
      FamilyRole.grandfather: _ItemSpec('Sage Jodhpuri Sherwani', 8500),
      FamilyRole.grandmother: _ItemSpec('Blush Tussar Saree', 7500),
      FamilyRole.father: _ItemSpec('Mint Linen Kurta', 4200),
      FamilyRole.mother: _ItemSpec('Blush Pink Anarkali', 6200),
      FamilyRole.son: _ItemSpec('Mini Mint Bandhgala', 2000),
      FamilyRole.daughter: _ItemSpec('Pastel Pink Lehenga', 2400),
      FamilyRole.male: _ItemSpec('Mint Linen Kurta', 4200),
      FamilyRole.female: _ItemSpec('Blush Pink Anarkali', 6200),
    },
  ),
  _ComboTemplate(
    id: 'festive-gold',
    name: 'Festive Gold Heritage',
    tagline: 'Old-money cream and gold — Eid, Karwa Chauth, the formal feast.',
    paletteColor: 0xFFB8860B,
    discountPercent: 10.0,
    priceByRole: {
      FamilyRole.grandfather: _ItemSpec('Cream Achkan with Gold Trim', 9500),
      FamilyRole.grandmother: _ItemSpec('Ivory Banarasi Saree', 8200),
      FamilyRole.father: _ItemSpec('Cream Silk Kurta with Gold Buttons', 5000),
      FamilyRole.mother: _ItemSpec('Gold Tissue Saree', 6800),
      FamilyRole.son: _ItemSpec('Cream Mini Kurta', 2100),
      FamilyRole.daughter: _ItemSpec('Gold Lehenga with Mirror Work', 2600),
      FamilyRole.male: _ItemSpec('Cream Silk Kurta with Gold Buttons', 5000),
      FamilyRole.female: _ItemSpec('Gold Tissue Saree', 6800),
    },
  ),
  _ComboTemplate(
    id: 'monochrome-modern',
    name: 'Monochrome Modern',
    tagline:
        'All-charcoal everything — a minimalist family that lets the silhouettes speak.',
    paletteColor: 0xFF2D2D2D,
    discountPercent: 10.0,
    priceByRole: {
      FamilyRole.grandfather: _ItemSpec('Charcoal Bandhgala', 6800),
      FamilyRole.grandmother: _ItemSpec('Black Mulmul Saree', 5800),
      FamilyRole.father: _ItemSpec('Slate Kurta-Pyjama', 3800),
      FamilyRole.mother: _ItemSpec('Charcoal Anarkali', 4800),
      FamilyRole.son: _ItemSpec('Mini Charcoal Kurta', 1500),
      FamilyRole.daughter: _ItemSpec('Black Tulle Lehenga', 1900),
      FamilyRole.male: _ItemSpec('Slate Kurta-Pyjama', 3800),
      FamilyRole.female: _ItemSpec('Charcoal Anarkali', 4800),
    },
  ),
];
