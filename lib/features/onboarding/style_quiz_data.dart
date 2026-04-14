/// Static data for the style quiz steps.
class QuizStep {
  final String title;
  final String subtitle;
  final List<String> options;
  final String dbField;

  const QuizStep({
    required this.title,
    required this.subtitle,
    required this.options,
    required this.dbField,
  });
}

const List<QuizStep> quizSteps = [
  QuizStep(
    title: 'Your Style',
    subtitle: 'What styles do you gravitate towards?',
    options: ['Classic', 'Modern', 'Ethnic', 'Casual', 'Streetwear', 'Minimalist'],
    dbField: 'preferred_styles',
  ),
  QuizStep(
    title: 'Fabric Feel',
    subtitle: 'Which fabrics do you prefer?',
    options: ['Cotton', 'Linen', 'Silk', 'Wool', 'Khadi', 'Blends'],
    dbField: 'preferred_fabrics',
  ),
  QuizStep(
    title: 'Colour Palette',
    subtitle: 'Pick your go-to colours',
    options: ['Neutrals', 'Pastels', 'Earth Tones', 'Bold & Bright', 'Monochromes', 'Jewel Tones'],
    dbField: 'preferred_colors',
  ),
  QuizStep(
    title: 'Occasions',
    subtitle: 'What do you dress up for most?',
    options: ['Office', 'Casual Outings', 'Weddings', 'Festivals', 'Parties', 'Travel'],
    dbField: 'preferred_occasions',
  ),
  QuizStep(
    title: 'Budget Range',
    subtitle: 'What\'s your comfort range per outfit?',
    options: ['Under \u20B92,000', '\u20B92,000 – \u20B95,000', '\u20B95,000 – \u20B910,000', '\u20B910,000 – \u20B920,000', '\u20B920,000+'],
    dbField: 'budget_range',
  ),
];
