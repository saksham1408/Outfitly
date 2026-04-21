/// A full body measurement set produced by the AI Body Scanner.
///
/// Kept as a lightweight value object so the review screen can edit a local
/// copy and then flush it to the existing `measurements` Supabase table via
/// the same `Map<String, double>` contract the manual flow already uses.
///
/// All values are in inches.
class MeasurementProfile {
  final double chest;
  final double waist;
  final double shoulder;
  final double sleeveLength;
  final double shirtLength;
  final double neck;
  final double trouserWaist;
  final double hip;
  final double thigh;
  final double inseam;
  final double trouserLength;

  const MeasurementProfile({
    required this.chest,
    required this.waist,
    required this.shoulder,
    required this.sleeveLength,
    required this.shirtLength,
    required this.neck,
    required this.trouserWaist,
    required this.hip,
    required this.thigh,
    required this.inseam,
    required this.trouserLength,
  });

  /// Produces the exact shape the `measurements` table + `OrderPayload`
  /// expect: snake_case keys → double values. The two flows (manual &
  /// AI scan) therefore remain interchangeable downstream.
  Map<String, double> toMap() => {
        'chest': chest,
        'waist': waist,
        'shoulder': shoulder,
        'sleeve_length': sleeveLength,
        'shirt_length': shirtLength,
        'neck': neck,
        'trouser_waist': trouserWaist,
        'hip': hip,
        'thigh': thigh,
        'inseam': inseam,
        'trouser_length': trouserLength,
      };

  MeasurementProfile copyWith({
    double? chest,
    double? waist,
    double? shoulder,
    double? sleeveLength,
    double? shirtLength,
    double? neck,
    double? trouserWaist,
    double? hip,
    double? thigh,
    double? inseam,
    double? trouserLength,
  }) {
    return MeasurementProfile(
      chest: chest ?? this.chest,
      waist: waist ?? this.waist,
      shoulder: shoulder ?? this.shoulder,
      sleeveLength: sleeveLength ?? this.sleeveLength,
      shirtLength: shirtLength ?? this.shirtLength,
      neck: neck ?? this.neck,
      trouserWaist: trouserWaist ?? this.trouserWaist,
      hip: hip ?? this.hip,
      thigh: thigh ?? this.thigh,
      inseam: inseam ?? this.inseam,
      trouserLength: trouserLength ?? this.trouserLength,
    );
  }
}
