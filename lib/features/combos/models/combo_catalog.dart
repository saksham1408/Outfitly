/// Static catalogs for the combo customization wizard.
///
/// Kept as plain const data so each screen can iterate without
/// pulling from Postgres — these surfaces don't change campaign
/// to campaign, so a Directus-backed catalog is overkill at MVP
/// scale. A future `combo_catalogs` table can swap this out
/// without changing any consumer; the screens just look up
/// against these maps + lists today.
library;

import 'family_member.dart';

/// Garment options surfaced on the garment-selection screen,
/// keyed by family role. Entries are ordered by how popular the
/// option tends to be for that role — first item is the safe
/// default if the user breezes through.
const Map<FamilyRole, List<String>> kGarmentsByRole = {
  FamilyRole.grandfather: <String>[
    'Sherwani',
    'Bandhgala',
    'Achkan',
    'Kurta',
  ],
  FamilyRole.grandmother: <String>[
    'Saree',
    'Salwar Suit',
    'Anarkali',
  ],
  FamilyRole.father: <String>[
    'Kurta',
    'Sherwani',
    'Bandhgala',
    'Suit',
    'Shirt',
    'Indo-Western',
  ],
  FamilyRole.mother: <String>[
    'Saree',
    'Anarkali',
    'Lehenga',
    'Salwar Suit',
    'Gown',
  ],
  FamilyRole.son: <String>[
    'Mini Kurta',
    'Mini Sherwani',
    'Shirt',
    'Bandhgala',
  ],
  FamilyRole.daughter: <String>[
    'Lehenga',
    'Frock',
    'Anarkali',
    'Salwar',
  ],
  // ── Couple-flow generic adults ──
  // Same option set as Father / Mother, just framed without the
  // parental role. Keeping them as separate map entries (vs.
  // aliasing father→male) means a future product team can tune
  // couple-only options independently — e.g. add a "Co-ord Set"
  // that doesn't make sense for a Father in a family wizard.
  FamilyRole.male: <String>[
    'Kurta',
    'Sherwani',
    'Bandhgala',
    'Suit',
    'Shirt',
    'Indo-Western',
  ],
  FamilyRole.female: <String>[
    'Saree',
    'Anarkali',
    'Lehenga',
    'Salwar Suit',
    'Gown',
  ],
};

/// Fabric swatches surfaced on the fabric-selection screen.
/// `paletteColor` is a 0xAARRGGBB int (kept dependency-free of
/// Flutter's `dart:ui`) — the picker tile renders this as the
/// fill colour of the swatch.
class FabricSwatch {
  const FabricSwatch({
    required this.name,
    required this.paletteColor,
    required this.tagline,
  });

  final String name;
  final int paletteColor;

  /// Two-line marketing description shown on the picker card so
  /// the user understands what they're picking beyond a name —
  /// helps a customer who has never bought a "Banarasi" before.
  final String tagline;
}

const List<FabricSwatch> kFabricCatalog = <FabricSwatch>[
  FabricSwatch(
    name: 'Silk',
    paletteColor: 0xFFB8860B,
    tagline: 'Lustrous, formal — the festive default.',
  ),
  FabricSwatch(
    name: 'Cotton',
    paletteColor: 0xFFF5EFDC,
    tagline: 'Breathable + soft — warm-weather everyday.',
  ),
  FabricSwatch(
    name: 'Linen',
    paletteColor: 0xFFE8D8B6,
    tagline: 'Lightweight, textured — relaxed daytime events.',
  ),
  FabricSwatch(
    name: 'Banarasi',
    paletteColor: 0xFF800020,
    tagline: 'Heritage zari weave — wedding-grade luxury.',
  ),
  FabricSwatch(
    name: 'Brocade',
    paletteColor: 0xFFC0A062,
    tagline: 'Raised metallic patterning — black-tie equivalent.',
  ),
  FabricSwatch(
    name: 'Velvet',
    paletteColor: 0xFF673147,
    tagline: 'Plush, weighty drape — winter occasions.',
  ),
  FabricSwatch(
    name: 'Tussar',
    paletteColor: 0xFFD2B48C,
    tagline: 'Wild-silk slub — earthy, undyed elegance.',
  ),
  FabricSwatch(
    name: 'Chiffon',
    paletteColor: 0xFFE6E6FA,
    tagline: 'Sheer, flowing — cocktail and cocktail-ish.',
  ),
  FabricSwatch(
    name: 'Georgette',
    paletteColor: 0xFFC8A2C8,
    tagline: 'Crepe-finish, swishy — modern Indo-Western pick.',
  ),
];

/// Size labels used on the size-selection screen. We split into
/// adult and kid scales so the picker shows age ranges for kids
/// (where shoppers think in years, not S/M/L) and clothing
/// sizes for adults.
const List<String> kAdultSizes = <String>[
  'XS',
  'S',
  'M',
  'L',
  'XL',
  'XXL',
];

const List<String> kKidSizes = <String>[
  '2-4Y',
  '4-6Y',
  '6-8Y',
  '8-10Y',
  '10-12Y',
  '12-14Y',
];

/// Sentinel string written into `sizeByMemberIndex` when a member
/// asks for a home tailor visit instead of picking a chart size.
/// The atelier sees this in `design_choices.size` on the order row
/// and coordinates the visit from the back office.
const String kSizeHomeTailor = 'Home Tailor Visit';

/// Prefix written into `sizeByMemberIndex` when a member fills
/// the manual-measurements sheet. Stored as
/// `"Custom: chest 38, waist 32, length 44, sleeve 22"` so the
/// values survive a round-trip through the orders table without
/// us needing a sidecar JSON column.
const String kSizeManualPrefix = 'Custom: ';

/// True if the sentinel string represents the "home tailor"
/// option (vs a chart size or manual measurements). Helpers
/// here keep the parsing in one place — the size card and the
/// completion check both call into this rather than duplicating
/// the prefix-string check.
bool isTailorVisitSize(String? value) =>
    value == kSizeHomeTailor;

bool isManualSize(String? value) =>
    value != null && value.startsWith(kSizeManualPrefix);
