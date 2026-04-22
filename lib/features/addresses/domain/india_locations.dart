/// Seed data for the Phase 2 State/City dropdowns on the Add Address
/// form. In Phase 3 this moves to a Supabase-served endpoint so we can
/// update it without a client release — the shape here is already
/// close to the row format we'll use.
///
/// The list is deliberately pragmatic (top metros + Tier 1/2 cities
/// customers actually order from), not an exhaustive gazetteer.
library;

/// Indian states & union territories (alphabetical). 28 + 8 = 36.
const List<String> indianStates = <String>[
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chhattisgarh',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
  'Andaman and Nicobar Islands',
  'Chandigarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Jammu and Kashmir',
  'Ladakh',
  'Lakshadweep',
  'Puducherry',
];

/// Major cities per state. We fall back to an "Other" entry so users
/// in smaller towns aren't locked out — picking it just means the
/// city will be saved as "Other" until Supabase seeding fills the gap.
const Map<String, List<String>> citiesByState = <String, List<String>>{
  'Andhra Pradesh': [
    'Visakhapatnam',
    'Vijayawada',
    'Guntur',
    'Nellore',
    'Tirupati',
    'Kakinada',
    'Rajahmundry',
    'Other',
  ],
  'Arunachal Pradesh': ['Itanagar', 'Naharlagun', 'Pasighat', 'Other'],
  'Assam': ['Guwahati', 'Dibrugarh', 'Silchar', 'Jorhat', 'Tezpur', 'Other'],
  'Bihar': [
    'Patna',
    'Gaya',
    'Bhagalpur',
    'Muzaffarpur',
    'Darbhanga',
    'Other',
  ],
  'Chhattisgarh': ['Raipur', 'Bhilai', 'Bilaspur', 'Korba', 'Durg', 'Other'],
  'Goa': ['Panaji', 'Margao', 'Vasco da Gama', 'Mapusa', 'Other'],
  'Gujarat': [
    'Ahmedabad',
    'Surat',
    'Vadodara',
    'Rajkot',
    'Bhavnagar',
    'Jamnagar',
    'Gandhinagar',
    'Other',
  ],
  'Haryana': [
    'Gurugram',
    'Faridabad',
    'Panipat',
    'Ambala',
    'Karnal',
    'Hisar',
    'Other',
  ],
  'Himachal Pradesh': [
    'Shimla',
    'Manali',
    'Dharamshala',
    'Solan',
    'Mandi',
    'Other',
  ],
  'Jharkhand': [
    'Ranchi',
    'Jamshedpur',
    'Dhanbad',
    'Bokaro',
    'Hazaribagh',
    'Other',
  ],
  'Karnataka': [
    'Bengaluru',
    'Mysuru',
    'Mangaluru',
    'Hubballi',
    'Belagavi',
    'Davanagere',
    'Other',
  ],
  'Kerala': [
    'Kochi',
    'Thiruvananthapuram',
    'Kozhikode',
    'Thrissur',
    'Kollam',
    'Kannur',
    'Other',
  ],
  'Madhya Pradesh': [
    'Bhopal',
    'Indore',
    'Gwalior',
    'Jabalpur',
    'Ujjain',
    'Sagar',
    'Other',
  ],
  'Maharashtra': [
    'Mumbai',
    'Pune',
    'Nagpur',
    'Nashik',
    'Aurangabad',
    'Thane',
    'Navi Mumbai',
    'Kolhapur',
    'Other',
  ],
  'Manipur': ['Imphal', 'Thoubal', 'Other'],
  'Meghalaya': ['Shillong', 'Tura', 'Other'],
  'Mizoram': ['Aizawl', 'Lunglei', 'Other'],
  'Nagaland': ['Kohima', 'Dimapur', 'Other'],
  'Odisha': [
    'Bhubaneswar',
    'Cuttack',
    'Rourkela',
    'Berhampur',
    'Sambalpur',
    'Other',
  ],
  'Punjab': [
    'Ludhiana',
    'Amritsar',
    'Jalandhar',
    'Patiala',
    'Bathinda',
    'Mohali',
    'Other',
  ],
  'Rajasthan': [
    'Jaipur',
    'Jodhpur',
    'Udaipur',
    'Kota',
    'Ajmer',
    'Bikaner',
    'Alwar',
    'Other',
  ],
  'Sikkim': ['Gangtok', 'Namchi', 'Other'],
  'Tamil Nadu': [
    'Chennai',
    'Coimbatore',
    'Madurai',
    'Tiruchirappalli',
    'Salem',
    'Tirunelveli',
    'Erode',
    'Other',
  ],
  'Telangana': [
    'Hyderabad',
    'Warangal',
    'Nizamabad',
    'Karimnagar',
    'Khammam',
    'Other',
  ],
  'Tripura': ['Agartala', 'Udaipur', 'Other'],
  'Uttar Pradesh': [
    'Lucknow',
    'Kanpur',
    'Varanasi',
    'Agra',
    'Noida',
    'Ghaziabad',
    'Prayagraj',
    'Meerut',
    'Other',
  ],
  'Uttarakhand': [
    'Dehradun',
    'Haridwar',
    'Rishikesh',
    'Haldwani',
    'Nainital',
    'Other',
  ],
  'West Bengal': [
    'Kolkata',
    'Howrah',
    'Siliguri',
    'Durgapur',
    'Asansol',
    'Kharagpur',
    'Other',
  ],
  'Andaman and Nicobar Islands': ['Port Blair', 'Other'],
  'Chandigarh': ['Chandigarh'],
  'Dadra and Nagar Haveli and Daman and Diu': ['Daman', 'Diu', 'Silvassa'],
  'Delhi': ['New Delhi', 'Delhi'],
  'Jammu and Kashmir': ['Srinagar', 'Jammu', 'Anantnag', 'Other'],
  'Ladakh': ['Leh', 'Kargil'],
  'Lakshadweep': ['Kavaratti'],
  'Puducherry': ['Puducherry', 'Karaikal', 'Mahe', 'Yanam'],
};

/// Convenience: list of cities for a state, defaulting to ['Other'].
List<String> citiesFor(String state) =>
    citiesByState[state] ?? const <String>['Other'];

/// Reverse lookup — try to match a geocoded city string (case-insensitive)
/// to the seed list so prefill selects the right dropdown option.
String? matchSeedCity(String state, String rawCity) {
  final options = citiesByState[state];
  if (options == null) return null;
  final needle = rawCity.trim().toLowerCase();
  for (final opt in options) {
    if (opt.toLowerCase() == needle) return opt;
  }
  return null;
}

/// Reverse lookup for state — tolerates "administrativeArea" returning
/// e.g. "MH" or "Maharashtra, India".
String? matchSeedState(String rawState) {
  final needle = rawState.trim().toLowerCase();
  for (final s in indianStates) {
    if (s.toLowerCase() == needle) return s;
  }
  // Loose contains — handles "Maharashtra, India" / "Rajasthan State".
  for (final s in indianStates) {
    if (needle.contains(s.toLowerCase())) return s;
  }
  return null;
}
