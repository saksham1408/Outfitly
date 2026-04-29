/// Static lookup table mapping ISO 3166-1 alpha-2 country codes to the
/// currency we want to render prices in for that country.
///
/// Why a static map (not a third-party `country_currency` package): the
/// canonical mapping is small, slow-changing, and the few weird cases
/// (Eurozone, dual-currency countries, dependencies) need product
/// judgement we can't import. We hand-curate the ~40 entries we care
/// about and fall through to USD for everything else — that's the
/// behaviour the master spec calls for in Condition C.
///
/// `decimalDigits` lives here too because currency-minor-units differ
/// from the en_US default in non-trivial ways: JPY/KRW/VND have zero
/// minor units, BHD/IQD/JOD have three. Using the wrong number of
/// decimals on a yen price ("¥5,000.00") looks broken to a Japanese
/// customer, so we get this right at the data layer instead of
/// special-casing in the formatter.
library;

class CurrencyInfo {
  const CurrencyInfo({
    required this.code,
    required this.symbol,
    required this.locale,
    this.decimalDigits = 2,
  });

  /// ISO 4217 three-letter code (e.g. `INR`, `USD`, `EUR`).
  final String code;

  /// The glyph rendered next to the amount. Most currencies have a
  /// single canonical glyph; we hand-pick the ambiguous ones (e.g.
  /// `$` belongs to USD, `A$` to AUD, `C$` to CAD).
  final String symbol;

  /// BCP 47 tag passed to `intl`'s NumberFormat to get locale-correct
  /// digit grouping and decimal separators (e.g. `en_IN` for the
  /// 1,50,000 lakh-style grouping; `de_DE` for `1.500,00`).
  final String locale;

  /// Currency minor units. 0 for JPY/KRW/VND/IDR/CLP, 2 for the
  /// majority, 3 for the Gulf currencies.
  final int decimalDigits;
}

/// Canonical fallback when location is unknown or the resolved currency
/// is unsupported. Spec Condition C.
const CurrencyInfo kFallbackCurrency = CurrencyInfo(
  code: 'USD',
  symbol: '\$',
  locale: 'en_US',
);

/// India — special-cased so the cart matches what every Indian
/// shopper expects (₹1,50,000, no decimals on display because the
/// catalog stores whole-rupee prices).
const CurrencyInfo kIndiaCurrency = CurrencyInfo(
  code: 'INR',
  symbol: '\u20B9',
  locale: 'en_IN',
  decimalDigits: 0,
);

/// ISO 3166-1 alpha-2 → currency. Covers the ~40 countries that
/// dominate global eCommerce traffic; everything else falls through to
/// [kFallbackCurrency]. The list is ordered by region for human
/// readability — the map is built up at file load time.
final Map<String, CurrencyInfo> kCountryToCurrency = {
  // ── South Asia ──
  'IN': kIndiaCurrency,
  'PK': const CurrencyInfo(code: 'PKR', symbol: 'Rs', locale: 'en_PK', decimalDigits: 0),
  'BD': const CurrencyInfo(code: 'BDT', symbol: '\u09F3', locale: 'bn_BD'),
  'LK': const CurrencyInfo(code: 'LKR', symbol: 'Rs', locale: 'en_LK'),
  'NP': const CurrencyInfo(code: 'NPR', symbol: 'Rs', locale: 'ne_NP'),

  // ── Eurozone (single currency, locale chosen for sensible grouping) ──
  'DE': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'de_DE'),
  'FR': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'fr_FR'),
  'ES': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'es_ES'),
  'IT': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'it_IT'),
  'NL': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'nl_NL'),
  'IE': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'en_IE'),
  'PT': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'pt_PT'),
  'BE': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'nl_BE'),
  'AT': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'de_AT'),
  'GR': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'el_GR'),
  'FI': const CurrencyInfo(code: 'EUR', symbol: '\u20AC', locale: 'fi_FI'),

  // ── Rest of Europe ──
  'GB': const CurrencyInfo(code: 'GBP', symbol: '\u00A3', locale: 'en_GB'),
  'CH': const CurrencyInfo(code: 'CHF', symbol: 'CHF', locale: 'de_CH'),
  'SE': const CurrencyInfo(code: 'SEK', symbol: 'kr', locale: 'sv_SE'),
  'NO': const CurrencyInfo(code: 'NOK', symbol: 'kr', locale: 'nb_NO'),
  'DK': const CurrencyInfo(code: 'DKK', symbol: 'kr', locale: 'da_DK'),
  'PL': const CurrencyInfo(code: 'PLN', symbol: 'z\u0142', locale: 'pl_PL'),
  'CZ': const CurrencyInfo(code: 'CZK', symbol: 'K\u010D', locale: 'cs_CZ'),
  'RU': const CurrencyInfo(code: 'RUB', symbol: '\u20BD', locale: 'ru_RU'),
  'TR': const CurrencyInfo(code: 'TRY', symbol: '\u20BA', locale: 'tr_TR'),

  // ── Americas ──
  'US': kFallbackCurrency,
  'CA': const CurrencyInfo(code: 'CAD', symbol: 'C\$', locale: 'en_CA'),
  'MX': const CurrencyInfo(code: 'MXN', symbol: '\$', locale: 'es_MX'),
  'BR': const CurrencyInfo(code: 'BRL', symbol: 'R\$', locale: 'pt_BR'),
  'AR': const CurrencyInfo(code: 'ARS', symbol: '\$', locale: 'es_AR'),
  'CL': const CurrencyInfo(code: 'CLP', symbol: '\$', locale: 'es_CL', decimalDigits: 0),

  // ── East & Southeast Asia ──
  'JP': const CurrencyInfo(code: 'JPY', symbol: '\u00A5', locale: 'ja_JP', decimalDigits: 0),
  'CN': const CurrencyInfo(code: 'CNY', symbol: '\u00A5', locale: 'zh_CN'),
  'KR': const CurrencyInfo(code: 'KRW', symbol: '\u20A9', locale: 'ko_KR', decimalDigits: 0),
  'HK': const CurrencyInfo(code: 'HKD', symbol: 'HK\$', locale: 'en_HK'),
  'TW': const CurrencyInfo(code: 'TWD', symbol: 'NT\$', locale: 'zh_TW'),
  'SG': const CurrencyInfo(code: 'SGD', symbol: 'S\$', locale: 'en_SG'),
  'MY': const CurrencyInfo(code: 'MYR', symbol: 'RM', locale: 'ms_MY'),
  'TH': const CurrencyInfo(code: 'THB', symbol: '\u0E3F', locale: 'th_TH'),
  'ID': const CurrencyInfo(code: 'IDR', symbol: 'Rp', locale: 'id_ID', decimalDigits: 0),
  'PH': const CurrencyInfo(code: 'PHP', symbol: '\u20B1', locale: 'en_PH'),
  'VN': const CurrencyInfo(code: 'VND', symbol: '\u20AB', locale: 'vi_VN', decimalDigits: 0),

  // ── Middle East & Africa ──
  'AE': const CurrencyInfo(code: 'AED', symbol: 'AED', locale: 'ar_AE'),
  'SA': const CurrencyInfo(code: 'SAR', symbol: 'SAR', locale: 'ar_SA'),
  'IL': const CurrencyInfo(code: 'ILS', symbol: '\u20AA', locale: 'he_IL'),
  'EG': const CurrencyInfo(code: 'EGP', symbol: 'E\u00A3', locale: 'ar_EG'),
  'ZA': const CurrencyInfo(code: 'ZAR', symbol: 'R', locale: 'en_ZA'),
  'NG': const CurrencyInfo(code: 'NGN', symbol: '\u20A6', locale: 'en_NG'),
  'KE': const CurrencyInfo(code: 'KES', symbol: 'KSh', locale: 'en_KE'),

  // ── Oceania ──
  'AU': const CurrencyInfo(code: 'AUD', symbol: 'A\$', locale: 'en_AU'),
  'NZ': const CurrencyInfo(code: 'NZD', symbol: 'NZ\$', locale: 'en_NZ'),
};

/// Resolve a country code to a [CurrencyInfo], normalising case and
/// stripping any region/script subtag noise. Returns [kFallbackCurrency]
/// for unknown codes — that's Condition C of the spec.
CurrencyInfo currencyForCountry(String? countryCode) {
  if (countryCode == null) return kFallbackCurrency;
  final normalised = countryCode.trim().toUpperCase();
  // Tolerate 3-letter ISO codes by mapping the well-known ones —
  // Flutter's platformDispatcher gives us alpha-2 today but
  // user-supplied locale strings ("IND", "USA") sometimes drift in.
  const alpha3to2 = <String, String>{
    'IND': 'IN',
    'USA': 'US',
    'GBR': 'GB',
    'CAN': 'CA',
    'AUS': 'AU',
    'JPN': 'JP',
    'DEU': 'DE',
    'FRA': 'FR',
  };
  final twoLetter = normalised.length == 3
      ? (alpha3to2[normalised] ?? normalised.substring(0, 2))
      : normalised;
  return kCountryToCurrency[twoLetter] ?? kFallbackCurrency;
}
