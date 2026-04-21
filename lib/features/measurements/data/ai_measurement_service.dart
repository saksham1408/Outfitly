import 'dart:io';

import '../models/measurement_profile.dart';

/// Front-end proxy for the (currently mocked) AI body-measurement engine.
///
/// The real engine will POST the two captured frames to a computer-vision
/// pipeline and stream back a set of body measurements. For now the
/// service returns a realistic, deterministic [MeasurementProfile] after
/// a 4-second delay so the UI can exercise the full scan-and-review flow
/// before the backend is live.
class AiMeasurementService {
  /// Takes a front-facing and a side-profile photo and returns a set of
  /// body measurements. The [File] arguments are accepted (rather than
  /// ignored) so the public API does not change when the real engine is
  /// wired up — the call site stays identical.
  Future<MeasurementProfile> calculateMeasurements(
    File frontImage,
    File sideImage,
  ) async {
    // Simulates the compute-heavy AI round-trip so the scanning screen
    // can run its laser + cycling-copy animation without flashing.
    await Future.delayed(const Duration(seconds: 4));

    // Realistic default profile — tuned to a typical Indian M-size build.
    // Replace with live data once the backend endpoint is live.
    return const MeasurementProfile(
      chest: 40.0,
      waist: 34.0,
      shoulder: 18.0,
      sleeveLength: 25.0,
      shirtLength: 30.0,
      neck: 15.5,
      trouserWaist: 34.0,
      hip: 40.0,
      thigh: 22.0,
      inseam: 30.0,
      trouserLength: 42.0,
    );
  }
}
