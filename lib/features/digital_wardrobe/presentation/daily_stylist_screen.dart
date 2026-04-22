import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/wardrobe_repository.dart';
import '../models/wardrobe_item.dart';
import '../services/daily_stylist_service.dart';

/// "What should I wear today?" — the premium dashboard that consumes
/// the user's uploaded closet + today's context to build a Mix & Match
/// outfit.
///
/// Shape:
///   * A weather ribbon (stubbed to 28°C sunny — easy to swap for a
///     live OpenWeather/WeatherKit call later).
///   * A three-way occasion toggle (Work / Casual / Date).
///   * A "Dress Me" CTA that hits Gemini.
///   * On success: a vertical Top → Bottom → Shoes stack with the
///     real photos from the user's closet + the stylist's reasoning.
class DailyStylistScreen extends StatefulWidget {
  const DailyStylistScreen({super.key});

  @override
  State<DailyStylistScreen> createState() => _DailyStylistScreenState();
}

class _DailyStylistScreenState extends State<DailyStylistScreen> {
  static const List<String> _occasions = ['Work', 'Casual', 'Date'];

  // TODO(weather): wire to a real forecast provider. For now a single
  // constant label stands in — when we plug in a proper weather
  // service we only touch this one site.
  final String _weather = '28°C Sunny';
  String _occasion = 'Work';

  final _service = DailyStylistService();
  DailyOutfit? _outfit;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WardrobeRepository.instance.ensureLoaded();
  }

  Future<void> _dressMe() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _outfit = null;
    });
    try {
      final items = WardrobeRepository.instance.items.value;
      final outfit = await _service.generateDailyOutfitFromWardrobe(
        userClothes: items,
        weather: _weather,
        event: _occasion,
      );
      if (!mounted) return;
      setState(() => _outfit = outfit);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Show the back chevron only when this screen was pushed (e.g.
        // from the Home card). When rendered as a bottom-nav tab there
        // is nothing to pop — Flutter's `automaticallyImplyLeading`
        // would still draw a default back button, so we explicitly set
        // leading to null in that case.
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                onPressed: () => context.pop(),
              )
            : null,
        title: Text(
          'Daily AI Stylist',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
        actions: [
          // Cross-navigation into the generative "Style a New Piece"
          // flow. Kept as a compact pill so it's discoverable without
          // stealing focus from the "Dress Me" primary action below.
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Material(
                color: AppColors.accent.withAlpha(40),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () =>
                      context.push('/digital-wardrobe/style-anchor'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'New Piece',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<WardrobeItem>>(
        valueListenable: WardrobeRepository.instance.items,
        builder: (context, items, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              _WeatherRibbon(weather: _weather),
              const SizedBox(height: 18),
              _SectionHeader(title: "What's the occasion today?"),
              const SizedBox(height: 10),
              _OccasionChips(
                options: _occasions,
                selected: _occasion,
                onChanged: (v) => setState(() => _occasion = v),
              ),
              const SizedBox(height: 22),
              _DressMeButton(
                loading: _loading,
                disabled: items.isEmpty,
                onTap: _dressMe,
              ),
              const SizedBox(height: 20),
              if (items.isEmpty) _NeedsClosetPrompt(),
              if (_outfit != null) ...[
                const SizedBox(height: 4),
                _OutfitStack(outfit: _outfit!),
                const SizedBox(height: 16),
                _ReasoningCard(text: _outfit!.reasoning),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _WeatherRibbon extends StatelessWidget {
  final String weather;
  const _WeatherRibbon({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withAlpha(210),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.wb_sunny_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: Colors.white.withAlpha(210),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  weather,
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.manrope(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }
}

class _OccasionChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _OccasionChips({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  IconData _iconFor(String o) {
    switch (o) {
      case 'Work':
        return Icons.work_outline_rounded;
      case 'Date':
        return Icons.favorite_outline_rounded;
      case 'Casual':
      default:
        return Icons.wb_sunny_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final o in options) ...[
          Expanded(
            child: _OccasionTile(
              label: o,
              icon: _iconFor(o),
              active: o == selected,
              onTap: () => onChanged(o),
            ),
          ),
          if (o != options.last) const SizedBox(width: 10),
        ],
      ],
    );
  }
}

class _OccasionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  const _OccasionTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active
                  ? AppColors.primary
                  : AppColors.primary.withAlpha(40),
              width: active ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: active ? Colors.white : AppColors.primary,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DressMeButton extends StatelessWidget {
  final bool loading;
  final bool disabled;
  final VoidCallback onTap;

  const _DressMeButton({
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: (loading || disabled) ? null : onTap,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.auto_awesome, size: 20),
        label: Text(
          loading ? 'Styling you…' : 'Dress Me',
          style: GoogleFonts.manrope(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.accent.withAlpha(150),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _NeedsClosetPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.primary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Upload a few clothes first',
                style: GoogleFonts.manrope(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The stylist only suggests outfits from pieces you own. '
            'Add a top, a bottom, and a pair of shoes to get started.',
            style: GoogleFonts.manrope(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/digital-wardrobe/closet'),
            icon: const Icon(Icons.add_a_photo_rounded, size: 16),
            label: Text(
              'Open My Closet',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withAlpha(100)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical Top → Bottom → Shoes mannequin. Accessories show as a
/// horizontal strip under the stack so the silhouette reads cleanly.
class _OutfitStack extends StatelessWidget {
  final DailyOutfit outfit;
  const _OutfitStack({required this.outfit});

  @override
  Widget build(BuildContext context) {
    if (outfit.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'The stylist couldn\'t find a matching outfit in your closet. '
          'Try adding more variety — at minimum one Top, one Bottom, and '
          'one pair of Shoes.',
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Column(
        children: [
          _OutfitSlot(slot: 'Top', item: outfit.top),
          const SizedBox(height: 10),
          _OutfitSlot(slot: 'Bottom', item: outfit.bottom),
          const SizedBox(height: 10),
          _OutfitSlot(slot: 'Shoes', item: outfit.shoes),
          if (outfit.accessories.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Finishing touches',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: outfit.accessories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final a = outfit.accessories[i];
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      a.imageUrl,
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, __) => Container(
                        width: 72,
                        height: 72,
                        color: AppColors.background,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.watch_outlined,
                          size: 24,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutfitSlot extends StatelessWidget {
  final String slot;
  final WardrobeItem? item;
  const _OutfitSlot({required this.slot, required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 54,
          child: Text(
            slot.toUpperCase(),
            style: GoogleFonts.manrope(
              fontSize: 10,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: item == null
                  ? Container(
                      color: AppColors.background,
                      alignment: Alignment.center,
                      child: Text(
                        'No $slot picked',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          item!.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, _, __) => Container(
                            color: AppColors.background,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.textTertiary,
                              size: 28,
                            ),
                          ),
                        ),
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item!.color} · ${item!.styleType}',
                              style: GoogleFonts.manrope(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasoningCard extends StatelessWidget {
  final String text;
  const _ReasoningCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withAlpha(60)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome,
            size: 16,
            color: AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why this outfit',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    height: 1.45,
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
