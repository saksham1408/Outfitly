import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/theme/theme.dart';

/// Mandate 5 — Functional Feed Sub-Tabs.
///
/// Elegant sub-tab strip + a placeholder feed that actually
/// reacts to the user's tap. Local [State.activeTab] flips
/// between four wardrobe styles, and the feed slot underneath
/// re-renders with a synced placeholder so the click feels
/// instant.
///
/// Production wiring will plug each tab into a filtered
/// `products` query (e.g. tag = 'ethnic'); the layout below
/// doesn't change when that lands.
class FeedSubTabs extends StatefulWidget {
  const FeedSubTabs({super.key});

  @override
  State<FeedSubTabs> createState() => _FeedSubTabsState();
}

class _FeedSubTabsState extends State<FeedSubTabs> {
  int _activeTab = 0;

  static const _tabs = <_TabSpec>[
    _TabSpec(label: 'All', accent: Color(0xFFEC4899)),
    _TabSpec(label: 'Ethnic', accent: Color(0xFFFBBF24)),
    _TabSpec(label: 'Casual', accent: Color(0xFF60A5FA)),
    _TabSpec(label: 'Workwear', accent: Color(0xFFA855F7)),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabStrip(
            tabs: _tabs,
            activeIndex: _activeTab,
            onTap: (i) => setState(() => _activeTab = i),
          ),
          const SizedBox(height: 14),
          // Animate the placeholder content so the user
          // sees a visible refresh on tab click.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, anim) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
            child: _FeedPlaceholder(
              key: ValueKey(_activeTab),
              tab: _tabs[_activeTab],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({required this.label, required this.accent});
  final String label;
  final Color accent;
}

class _TabStrip extends StatelessWidget {
  const _TabStrip({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
  });

  final List<_TabSpec> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final tab = tabs[i];
          final active = i == activeIndex;
          return GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: active ? tab.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: active
                      ? tab.accent
                      : AppColors.primary.withAlpha(20),
                ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: tab.accent.withAlpha(140),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                tab.label,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: active ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FeedPlaceholder extends StatelessWidget {
  const _FeedPlaceholder({super.key, required this.tab});

  final _TabSpec tab;

  @override
  Widget build(BuildContext context) {
    // Tab-specific copy so the user sees the click do
    // something tangible even with placeholder data.
    final body = _bodyFor(tab.label);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tab.accent.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tab.accent.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(tab.accent),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body.title,
                  style: GoogleFonts.newsreader(
                    fontSize: 17,
                    fontStyle: FontStyle.italic,
                    color: AppColors.primary,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body.caption,
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String title, String caption}) _bodyFor(String label) {
    switch (label) {
      case 'Ethnic':
        return (
          title: 'Syncing your ethnic capsule…',
          caption:
              'Kurtas, sarees, sherwanis — everything woven for the festive feast.',
        );
      case 'Casual':
        return (
          title: 'Syncing your casual capsule…',
          caption:
              'Indo-western, breezy linens, weekend-friendly silhouettes.',
        );
      case 'Workwear':
        return (
          title: 'Syncing your workwear capsule…',
          caption:
              'Bandhgalas, modern kurta-blazers, clean-line co-ords for the office.',
        );
      case 'All':
      default:
        return (
          title: 'Syncing your full wardrobe…',
          caption: 'Every piece you\'ve digitised, in one feed.',
        );
    }
  }
}
