class MeasurementField {
  final String key;
  final String label;
  final String hint;
  final String unit;

  const MeasurementField({
    required this.key,
    required this.label,
    required this.hint,
    this.unit = 'inches',
  });
}

const upperBodyFields = [
  MeasurementField(key: 'chest', label: 'Chest', hint: '38'),
  MeasurementField(key: 'waist', label: 'Waist', hint: '34'),
  MeasurementField(key: 'shoulder', label: 'Shoulder', hint: '18'),
  MeasurementField(key: 'sleeve_length', label: 'Sleeve Length', hint: '25'),
  MeasurementField(key: 'shirt_length', label: 'Shirt Length', hint: '30'),
  MeasurementField(key: 'neck', label: 'Neck', hint: '15.5'),
];

const lowerBodyFields = [
  MeasurementField(key: 'trouser_waist', label: 'Trouser Waist', hint: '34'),
  MeasurementField(key: 'hip', label: 'Hip', hint: '40'),
  MeasurementField(key: 'thigh', label: 'Thigh', hint: '22'),
  MeasurementField(key: 'inseam', label: 'Inseam', hint: '32'),
  MeasurementField(key: 'trouser_length', label: 'Trouser Length', hint: '42'),
];
