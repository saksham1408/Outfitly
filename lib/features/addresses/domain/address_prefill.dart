import 'package:flutter/foundation.dart';

/// A partial address snapshot used to pre-populate the [AddAddressScreen]
/// when the user arrives there from the "Use Current Location" flow or
/// some future deep-link. All fields are optional — the form still
/// validates everything on submit.
@immutable
class AddressPrefill {
  final String? city;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;

  const AddressPrefill({
    this.city,
    this.state,
    this.pincode,
    this.latitude,
    this.longitude,
  });
}
