/// ISO 3166-1 alpha-2 → phone dial code + display metadata.
///
/// Why a separate file from [country_currency_map.dart]: the currency
/// table only lists countries we *render prices for*; the dial-code
/// table needs to cover the same set so the country picker stays
/// consistent. We also bake the display name (English) and the max
/// "national subscriber" length so the phone field can validate
/// without pulling in a 400KB libphonenumber port for v1.
///
/// Maximum lengths are *typical* — they're the upper bound the picker
/// uses for input length. We don't enforce that the digits parse as a
/// real number; that's a server-side concern when SMS OTP lands.
library;

class CountryDialInfo {
  const CountryDialInfo({
    required this.code,
    required this.name,
    required this.dialCode,
    required this.maxLength,
    required this.flag,
    this.exampleLocal = '',
  });

  /// ISO 3166-1 alpha-2 (`IN`, `US`, `GB`).
  final String code;

  /// English display name. Localising this is a future iteration —
  /// for v1 the picker is English-only; the rest of the UI mirrors it.
  final String name;

  /// E.164 dial code with leading `+` (`+91`, `+1`, `+44`).
  final String dialCode;

  /// Maximum digits we accept after the dial code. Most countries are
  /// 9–11; we go off the upper bound (NSN) from the ITU-T E.164 spec.
  final int maxLength;

  /// Emoji regional-indicator flag. Saves us shipping a 600-icon flag
  /// font; modern iOS/Android render these natively.
  final String flag;

  /// Local-format hint for the input placeholder (`98765 43210`,
  /// `(555) 123-4567`). Empty string = no example, render a generic
  /// digits hint instead.
  final String exampleLocal;
}

/// All ~40 countries we recognise across the app — same set as the
/// currency map so a country picker never picks something we then can't
/// price for. Ordered alphabetically by name for the picker UI; the map
/// itself is keyed by ISO-2 for O(1) lookup.
const Map<String, CountryDialInfo> kCountryDialCodes = {
  // South Asia
  'IN': CountryDialInfo(
    code: 'IN',
    name: 'India',
    dialCode: '+91',
    maxLength: 10,
    flag: '\u{1F1EE}\u{1F1F3}',
    exampleLocal: '98765 43210',
  ),
  'PK': CountryDialInfo(
    code: 'PK',
    name: 'Pakistan',
    dialCode: '+92',
    maxLength: 10,
    flag: '\u{1F1F5}\u{1F1F0}',
    exampleLocal: '300 1234567',
  ),
  'BD': CountryDialInfo(
    code: 'BD',
    name: 'Bangladesh',
    dialCode: '+880',
    maxLength: 10,
    flag: '\u{1F1E7}\u{1F1E9}',
    exampleLocal: '1712 345678',
  ),
  'LK': CountryDialInfo(
    code: 'LK',
    name: 'Sri Lanka',
    dialCode: '+94',
    maxLength: 9,
    flag: '\u{1F1F1}\u{1F1F0}',
    exampleLocal: '71 234 5678',
  ),
  'NP': CountryDialInfo(
    code: 'NP',
    name: 'Nepal',
    dialCode: '+977',
    maxLength: 10,
    flag: '\u{1F1F3}\u{1F1F5}',
    exampleLocal: '98 12345678',
  ),

  // Eurozone
  'DE': CountryDialInfo(
    code: 'DE',
    name: 'Germany',
    dialCode: '+49',
    maxLength: 11,
    flag: '\u{1F1E9}\u{1F1EA}',
    exampleLocal: '1512 3456789',
  ),
  'FR': CountryDialInfo(
    code: 'FR',
    name: 'France',
    dialCode: '+33',
    maxLength: 9,
    flag: '\u{1F1EB}\u{1F1F7}',
    exampleLocal: '6 12 34 56 78',
  ),
  'ES': CountryDialInfo(
    code: 'ES',
    name: 'Spain',
    dialCode: '+34',
    maxLength: 9,
    flag: '\u{1F1EA}\u{1F1F8}',
    exampleLocal: '612 34 56 78',
  ),
  'IT': CountryDialInfo(
    code: 'IT',
    name: 'Italy',
    dialCode: '+39',
    maxLength: 10,
    flag: '\u{1F1EE}\u{1F1F9}',
    exampleLocal: '312 345 6789',
  ),
  'NL': CountryDialInfo(
    code: 'NL',
    name: 'Netherlands',
    dialCode: '+31',
    maxLength: 9,
    flag: '\u{1F1F3}\u{1F1F1}',
    exampleLocal: '6 12345678',
  ),
  'IE': CountryDialInfo(
    code: 'IE',
    name: 'Ireland',
    dialCode: '+353',
    maxLength: 9,
    flag: '\u{1F1EE}\u{1F1EA}',
    exampleLocal: '85 123 4567',
  ),
  'PT': CountryDialInfo(
    code: 'PT',
    name: 'Portugal',
    dialCode: '+351',
    maxLength: 9,
    flag: '\u{1F1F5}\u{1F1F9}',
    exampleLocal: '912 345 678',
  ),
  'BE': CountryDialInfo(
    code: 'BE',
    name: 'Belgium',
    dialCode: '+32',
    maxLength: 9,
    flag: '\u{1F1E7}\u{1F1EA}',
    exampleLocal: '470 12 34 56',
  ),
  'AT': CountryDialInfo(
    code: 'AT',
    name: 'Austria',
    dialCode: '+43',
    maxLength: 11,
    flag: '\u{1F1E6}\u{1F1F9}',
    exampleLocal: '664 1234567',
  ),
  'GR': CountryDialInfo(
    code: 'GR',
    name: 'Greece',
    dialCode: '+30',
    maxLength: 10,
    flag: '\u{1F1EC}\u{1F1F7}',
    exampleLocal: '691 234 5678',
  ),
  'FI': CountryDialInfo(
    code: 'FI',
    name: 'Finland',
    dialCode: '+358',
    maxLength: 10,
    flag: '\u{1F1EB}\u{1F1EE}',
    exampleLocal: '41 2345678',
  ),

  // Rest of Europe
  'GB': CountryDialInfo(
    code: 'GB',
    name: 'United Kingdom',
    dialCode: '+44',
    maxLength: 10,
    flag: '\u{1F1EC}\u{1F1E7}',
    exampleLocal: '7700 900123',
  ),
  'CH': CountryDialInfo(
    code: 'CH',
    name: 'Switzerland',
    dialCode: '+41',
    maxLength: 9,
    flag: '\u{1F1E8}\u{1F1ED}',
    exampleLocal: '78 123 45 67',
  ),
  'SE': CountryDialInfo(
    code: 'SE',
    name: 'Sweden',
    dialCode: '+46',
    maxLength: 9,
    flag: '\u{1F1F8}\u{1F1EA}',
    exampleLocal: '70 123 45 67',
  ),
  'NO': CountryDialInfo(
    code: 'NO',
    name: 'Norway',
    dialCode: '+47',
    maxLength: 8,
    flag: '\u{1F1F3}\u{1F1F4}',
    exampleLocal: '406 12 345',
  ),
  'DK': CountryDialInfo(
    code: 'DK',
    name: 'Denmark',
    dialCode: '+45',
    maxLength: 8,
    flag: '\u{1F1E9}\u{1F1F0}',
    exampleLocal: '20 12 34 56',
  ),
  'PL': CountryDialInfo(
    code: 'PL',
    name: 'Poland',
    dialCode: '+48',
    maxLength: 9,
    flag: '\u{1F1F5}\u{1F1F1}',
    exampleLocal: '512 345 678',
  ),
  'CZ': CountryDialInfo(
    code: 'CZ',
    name: 'Czechia',
    dialCode: '+420',
    maxLength: 9,
    flag: '\u{1F1E8}\u{1F1FF}',
    exampleLocal: '601 123 456',
  ),
  'RU': CountryDialInfo(
    code: 'RU',
    name: 'Russia',
    dialCode: '+7',
    maxLength: 10,
    flag: '\u{1F1F7}\u{1F1FA}',
    exampleLocal: '912 345 67 89',
  ),
  'TR': CountryDialInfo(
    code: 'TR',
    name: 'Türkiye',
    dialCode: '+90',
    maxLength: 10,
    flag: '\u{1F1F9}\u{1F1F7}',
    exampleLocal: '532 123 4567',
  ),

  // Americas
  'US': CountryDialInfo(
    code: 'US',
    name: 'United States',
    dialCode: '+1',
    maxLength: 10,
    flag: '\u{1F1FA}\u{1F1F8}',
    exampleLocal: '(555) 123-4567',
  ),
  'CA': CountryDialInfo(
    code: 'CA',
    name: 'Canada',
    dialCode: '+1',
    maxLength: 10,
    flag: '\u{1F1E8}\u{1F1E6}',
    exampleLocal: '(555) 123-4567',
  ),
  'MX': CountryDialInfo(
    code: 'MX',
    name: 'Mexico',
    dialCode: '+52',
    maxLength: 10,
    flag: '\u{1F1F2}\u{1F1FD}',
    exampleLocal: '55 1234 5678',
  ),
  'BR': CountryDialInfo(
    code: 'BR',
    name: 'Brazil',
    dialCode: '+55',
    maxLength: 11,
    flag: '\u{1F1E7}\u{1F1F7}',
    exampleLocal: '11 91234-5678',
  ),
  'AR': CountryDialInfo(
    code: 'AR',
    name: 'Argentina',
    dialCode: '+54',
    maxLength: 10,
    flag: '\u{1F1E6}\u{1F1F7}',
    exampleLocal: '11 1234-5678',
  ),
  'CL': CountryDialInfo(
    code: 'CL',
    name: 'Chile',
    dialCode: '+56',
    maxLength: 9,
    flag: '\u{1F1E8}\u{1F1F1}',
    exampleLocal: '9 1234 5678',
  ),

  // East & Southeast Asia
  'JP': CountryDialInfo(
    code: 'JP',
    name: 'Japan',
    dialCode: '+81',
    maxLength: 10,
    flag: '\u{1F1EF}\u{1F1F5}',
    exampleLocal: '90 1234 5678',
  ),
  'CN': CountryDialInfo(
    code: 'CN',
    name: 'China',
    dialCode: '+86',
    maxLength: 11,
    flag: '\u{1F1E8}\u{1F1F3}',
    exampleLocal: '131 2345 6789',
  ),
  'KR': CountryDialInfo(
    code: 'KR',
    name: 'South Korea',
    dialCode: '+82',
    maxLength: 10,
    flag: '\u{1F1F0}\u{1F1F7}',
    exampleLocal: '10 1234 5678',
  ),
  'HK': CountryDialInfo(
    code: 'HK',
    name: 'Hong Kong',
    dialCode: '+852',
    maxLength: 8,
    flag: '\u{1F1ED}\u{1F1F0}',
    exampleLocal: '5123 4567',
  ),
  'TW': CountryDialInfo(
    code: 'TW',
    name: 'Taiwan',
    dialCode: '+886',
    maxLength: 9,
    flag: '\u{1F1F9}\u{1F1FC}',
    exampleLocal: '912 345 678',
  ),
  'SG': CountryDialInfo(
    code: 'SG',
    name: 'Singapore',
    dialCode: '+65',
    maxLength: 8,
    flag: '\u{1F1F8}\u{1F1EC}',
    exampleLocal: '8123 4567',
  ),
  'MY': CountryDialInfo(
    code: 'MY',
    name: 'Malaysia',
    dialCode: '+60',
    maxLength: 10,
    flag: '\u{1F1F2}\u{1F1FE}',
    exampleLocal: '12-345 6789',
  ),
  'TH': CountryDialInfo(
    code: 'TH',
    name: 'Thailand',
    dialCode: '+66',
    maxLength: 9,
    flag: '\u{1F1F9}\u{1F1ED}',
    exampleLocal: '81 234 5678',
  ),
  'ID': CountryDialInfo(
    code: 'ID',
    name: 'Indonesia',
    dialCode: '+62',
    maxLength: 11,
    flag: '\u{1F1EE}\u{1F1E9}',
    exampleLocal: '812 3456 789',
  ),
  'PH': CountryDialInfo(
    code: 'PH',
    name: 'Philippines',
    dialCode: '+63',
    maxLength: 10,
    flag: '\u{1F1F5}\u{1F1ED}',
    exampleLocal: '917 123 4567',
  ),
  'VN': CountryDialInfo(
    code: 'VN',
    name: 'Vietnam',
    dialCode: '+84',
    maxLength: 9,
    flag: '\u{1F1FB}\u{1F1F3}',
    exampleLocal: '912 345 678',
  ),

  // Middle East & Africa
  'AE': CountryDialInfo(
    code: 'AE',
    name: 'United Arab Emirates',
    dialCode: '+971',
    maxLength: 9,
    flag: '\u{1F1E6}\u{1F1EA}',
    exampleLocal: '50 123 4567',
  ),
  'SA': CountryDialInfo(
    code: 'SA',
    name: 'Saudi Arabia',
    dialCode: '+966',
    maxLength: 9,
    flag: '\u{1F1F8}\u{1F1E6}',
    exampleLocal: '51 234 5678',
  ),
  'IL': CountryDialInfo(
    code: 'IL',
    name: 'Israel',
    dialCode: '+972',
    maxLength: 9,
    flag: '\u{1F1EE}\u{1F1F1}',
    exampleLocal: '50 123 4567',
  ),
  'EG': CountryDialInfo(
    code: 'EG',
    name: 'Egypt',
    dialCode: '+20',
    maxLength: 10,
    flag: '\u{1F1EA}\u{1F1EC}',
    exampleLocal: '100 123 4567',
  ),
  'ZA': CountryDialInfo(
    code: 'ZA',
    name: 'South Africa',
    dialCode: '+27',
    maxLength: 9,
    flag: '\u{1F1FF}\u{1F1E6}',
    exampleLocal: '71 123 4567',
  ),
  'NG': CountryDialInfo(
    code: 'NG',
    name: 'Nigeria',
    dialCode: '+234',
    maxLength: 10,
    flag: '\u{1F1F3}\u{1F1EC}',
    exampleLocal: '802 123 4567',
  ),
  'KE': CountryDialInfo(
    code: 'KE',
    name: 'Kenya',
    dialCode: '+254',
    maxLength: 9,
    flag: '\u{1F1F0}\u{1F1EA}',
    exampleLocal: '712 345 678',
  ),

  // Oceania
  'AU': CountryDialInfo(
    code: 'AU',
    name: 'Australia',
    dialCode: '+61',
    maxLength: 9,
    flag: '\u{1F1E6}\u{1F1FA}',
    exampleLocal: '412 345 678',
  ),
  'NZ': CountryDialInfo(
    code: 'NZ',
    name: 'New Zealand',
    dialCode: '+64',
    maxLength: 9,
    flag: '\u{1F1F3}\u{1F1FF}',
    exampleLocal: '21 123 4567',
  ),
};

/// Default selection for the picker. India because that's the launch
/// market and the catalog is INR-denominated.
const String kDefaultCountryCode = 'IN';

/// Lookup with safe fallback to India. Use this everywhere instead of
/// hitting the map directly so an unknown code (legacy DB row, future
/// country we haven't added yet) doesn't crash the UI.
CountryDialInfo dialInfoForCountry(String? code) {
  if (code == null) return kCountryDialCodes[kDefaultCountryCode]!;
  return kCountryDialCodes[code.trim().toUpperCase()] ??
      kCountryDialCodes[kDefaultCountryCode]!;
}

/// Picker-ordered list (alphabetical by display name, with India
/// pinned first since it's the dominant market). Computed once at
/// load time; cheap.
final List<CountryDialInfo> kCountryDialList = () {
  final list = kCountryDialCodes.values.toList()
    ..sort((a, b) => a.name.compareTo(b.name));
  // Pin India to the top of the list.
  final india = list.firstWhere((c) => c.code == 'IN');
  list
    ..remove(india)
    ..insert(0, india);
  return List<CountryDialInfo>.unmodifiable(list);
}();
