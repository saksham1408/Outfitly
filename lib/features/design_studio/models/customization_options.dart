// Static data for the design studio customization steps.

class CustomizationOption {
  final String id;
  final String label;
  final String? description;
  final String? iconPlaceholder;

  const CustomizationOption({
    required this.id,
    required this.label,
    this.description,
    this.iconPlaceholder,
  });
}

class CustomizationStep {
  final String title;
  final String subtitle;
  final List<CustomizationOption> options;

  const CustomizationStep({
    required this.title,
    required this.subtitle,
    required this.options,
  });
}

// ── Collar Options ──
const collarOptions = CustomizationStep(
  title: 'Collar Style',
  subtitle: 'Choose how you want the collar',
  options: [
    CustomizationOption(id: 'spread', label: 'Spread', description: 'Classic wide collar'),
    CustomizationOption(id: 'button_down', label: 'Button Down', description: 'Casual buttoned tips'),
    CustomizationOption(id: 'mandarin', label: 'Mandarin', description: 'Band / stand collar'),
    CustomizationOption(id: 'cutaway', label: 'Cutaway', description: 'Wide-angle formal'),
    CustomizationOption(id: 'club', label: 'Club', description: 'Rounded tips'),
    CustomizationOption(id: 'wingtip', label: 'Wingtip', description: 'For bow ties & formal'),
  ],
);

// ── Sleeve Options ──
const sleeveOptions = CustomizationStep(
  title: 'Sleeve Style',
  subtitle: 'Pick the sleeve length and cuff',
  options: [
    CustomizationOption(id: 'long_barrel', label: 'Long — Barrel Cuff', description: 'Classic button cuff'),
    CustomizationOption(id: 'long_french', label: 'Long — French Cuff', description: 'For cufflinks'),
    CustomizationOption(id: 'half', label: 'Half Sleeve', description: 'Above the elbow'),
    CustomizationOption(id: 'three_quarter', label: '3/4 Sleeve', description: 'Below the elbow'),
    CustomizationOption(id: 'rolled', label: 'Rolled Tab', description: 'Adjustable roll-up tab'),
  ],
);

// ── Pocket Options ──
const pocketOptions = CustomizationStep(
  title: 'Pocket',
  subtitle: 'Add a chest pocket?',
  options: [
    CustomizationOption(id: 'none', label: 'No Pocket', description: 'Clean minimal look'),
    CustomizationOption(id: 'patch', label: 'Patch Pocket', description: 'Standard chest pocket'),
    CustomizationOption(id: 'flap', label: 'Flap Pocket', description: 'With a folded flap'),
    CustomizationOption(id: 'welt', label: 'Welt Pocket', description: 'Subtle slit pocket'),
  ],
);

// ── Fit Options ──
const fitOptions = CustomizationStep(
  title: 'Fit',
  subtitle: 'How do you want it to feel?',
  options: [
    CustomizationOption(id: 'slim', label: 'Slim Fit', description: 'Tapered, close to body'),
    CustomizationOption(id: 'regular', label: 'Regular Fit', description: 'Comfortable, classic'),
    CustomizationOption(id: 'relaxed', label: 'Relaxed Fit', description: 'Loose and airy'),
  ],
);

// ── Monogram Options ──
const monogramOptions = CustomizationStep(
  title: 'Monogram',
  subtitle: 'Add a personal touch',
  options: [
    CustomizationOption(id: 'none', label: 'No Monogram'),
    CustomizationOption(id: 'chest', label: 'Chest', description: 'Left chest embroidery'),
    CustomizationOption(id: 'cuff', label: 'Cuff', description: 'On the sleeve cuff'),
    CustomizationOption(id: 'collar', label: 'Collar', description: 'Inner collar stitch'),
  ],
);

/// All customization steps in order.
const allCustomizationSteps = [
  collarOptions,
  sleeveOptions,
  pocketOptions,
  fitOptions,
  monogramOptions,
];
