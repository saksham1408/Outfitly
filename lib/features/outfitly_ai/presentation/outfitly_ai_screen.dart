import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../models/outfit_recommendation.dart';
import '../services/ai_stylist_service.dart';

class OutfitlyAiScreen extends StatefulWidget {
  const OutfitlyAiScreen({super.key});

  @override
  State<OutfitlyAiScreen> createState() => _OutfitlyAiScreenState();
}

class _OutfitlyAiScreenState extends State<OutfitlyAiScreen> {
  final _stylist = AiStylistService();

  static const _moods = [
    'Confident',
    'Relaxed',
    'Romantic',
    'Bold',
    'Minimalist',
    'Playful',
  ];
  static const _events = [
    'Office Meeting',
    'Brunch Date',
    'Wedding',
    'Evening Party',
    'Travel Day',
    'Casual Outing',
  ];
  static const _weathers = [
    'Hot',
    'Warm',
    'Mild',
    'Cool',
    'Cold',
    'Rainy',
  ];

  String? _mood;
  String? _event;
  String? _weather;

  OutfitRecommendation? _result;
  bool _loading = false;

  bool get _canGenerate =>
      !_loading && _mood != null && _event != null && _weather != null;

  Future<void> _generate() async {
    if (!_canGenerate) return;
    setState(() {
      _loading = true;
      _result = null;
    });
    final rec = await _stylist.generateOutfit(_mood!, _event!, _weather!);
    if (!mounted) return;
    setState(() {
      _result = rec;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'VASTRAHUB AI',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            _buildHero(),
            const SizedBox(height: 14),
            _buildRecreateLookCard(),
            const SizedBox(height: 24),
            _sectionLabel('MOOD'),
            const SizedBox(height: 10),
            _chipGroup(_moods, _mood, (v) => setState(() => _mood = v)),
            const SizedBox(height: 24),
            _sectionLabel('EVENT'),
            const SizedBox(height: 10),
            _chipGroup(_events, _event, (v) => setState(() => _event = v)),
            const SizedBox(height: 24),
            _sectionLabel('WEATHER'),
            const SizedBox(height: 10),
            _chipGroup(_weathers, _weather, (v) => setState(() => _weather = v)),
            const SizedBox(height: 32),
            _buildGenerateButton(),
            if (_loading) ...[
              const SizedBox(height: 32),
              _buildLoading(),
            ],
            if (_result != null) ...[
              const SizedBox(height: 32),
              _buildResult(_result!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withAlpha(220),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your personal AI stylist',
                  style: GoogleFonts.newsreader(
                    fontSize: 18,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tell me how you feel, where you\'re going, and what the weather\'s like — I\'ll style you head-to-toe.',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.white.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tappable card under the hero that hands off to the AI Look
  /// Recreator. Uses warm accent colours (vs. the cool primary of the
  /// hero) so the two surfaces read as distinct entry points: "style
  /// me" vs. "recreate this look I saw".
  Widget _buildRecreateLookCard() {
    return GestureDetector(
      onTap: () => context.push('/recreate-look'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.accent.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent.withAlpha(60)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(30),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.image_search_rounded,
                color: AppColors.accent,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recreate a Look from a Photo',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reverse-engineer any outfit on a budget',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: AppColors.accent,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: AppColors.textTertiary,
        ),
      );

  Widget _chipGroup(
    List<String> options,
    String? selected,
    ValueChanged<String> onSelect,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((o) {
        final isSel = selected == o;
        return ChoiceChip(
          label: Text(o),
          selected: isSel,
          onSelected: (_) => onSelect(o),
          labelStyle: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
            color: isSel ? Colors.white : AppColors.textSecondary,
          ),
          backgroundColor: AppColors.surface,
          selectedColor: AppColors.primary,
          side: BorderSide(
            color: isSel ? AppColors.primary : AppColors.border,
          ),
          showCheckmark: false,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        );
      }).toList(),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canGenerate ? _generate : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border.withAlpha(80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          'GENERATE OUTFIT',
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        children: [
          const CircularProgressIndicator(color: AppColors.accent),
          const SizedBox(height: 12),
          Text(
            'Consulting the stylist…',
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(OutfitRecommendation rec) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withAlpha(80)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your look',
            style: GoogleFonts.newsreader(
              fontSize: 22,
              fontStyle: FontStyle.italic,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          _outfitRow(Icons.dry_cleaning_outlined, 'Top', rec.top),
          _outfitRow(Icons.straighten_rounded, 'Bottom', rec.bottom),
          _outfitRow(Icons.ice_skating_outlined, 'Shoes', rec.shoes),
          _outfitRow(Icons.diamond_outlined, 'Accessories', rec.accessories),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accent.withAlpha(12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.accent.withAlpha(30)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology_outlined,
                    color: AppColors.accent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rec.reasoning,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _outfitRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? '—' : value,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
