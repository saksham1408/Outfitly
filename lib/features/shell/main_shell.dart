import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme.dart';
import '../catalog/presentation/home/home_screen.dart';
import '../wardrobe_calendar/presentation/wardrobe_calendar_screen.dart';
import 'ai_tools_sheet.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  // Two real root tabs (Home + Closet). Between them sits a non-tab
  // "AI" launcher that opens [showAiToolsSheet] — VASTRAHUB AI,
  // Dress Me, and Recreate a Look all live behind it. The launcher
  // never sets `_currentIndex`, so tapping it doesn't change the
  // visible screen; the modal opens on top of whatever you were
  // already on.
  final _screens = const [
    HomeScreen(),
    WardrobeCalendarScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _navItem(1, Icons.checkroom_outlined,
                    Icons.checkroom_rounded, 'Closet'),
                // Loop — the social Friend Closet entry. Doesn't have
                // a screen instance in `_screens` because the dashboard
                // lives on its own pushed route (so it gets a back
                // arrow); we route via context.push('/social') and
                // never set _currentIndex for it.
                _LoopNavButton(
                  onTap: () => context.push('/social'),
                ),
                // AI launcher — positioned at the right edge so it
                // anchors the nav as the "creative tools" pole
                // opposite Home (the "browse" pole). Visually
                // distinct (brand-coloured pill, hamburger icon)
                // because tapping it pops a sheet instead of
                // switching tabs.
                _AiLauncherButton(
                  onTap: () => showAiToolsSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? AppColors.primary : AppColors.textTertiary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.primary : AppColors.textTertiary,
              ),
              overflow: TextOverflow.visible,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// "Loop" nav button — same shape as a regular tab item but routes
/// via `context.push('/social')` instead of switching the IndexedStack
/// index. The Loop dashboard then renders with a real back arrow so
/// users can return without an extra mental model ("which tab am I
/// in?"). The button never appears as `isActive` on the bottom nav
/// because it's a route, not a tab.
class _LoopNavButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LoopNavButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              // Refresh-arrow loop — reads as "going around" /
              // "circulating" which is exactly what the social
              // borrow flow does.
              Icons.loop_rounded,
              size: 22,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 2),
            Text(
              'Loop',
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textTertiary,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

/// Centre launcher in the bottom nav. Hamburger-style 3-line icon
/// over a brand-coloured pill so it reads as "more options here"
/// rather than as a tab destination. Sized slightly larger than the
/// adjacent nav items so it feels like a primary action.
class _AiLauncherButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AiLauncherButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(60),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                // Three horizontal lines — reads as "menu of AI tools".
                Icons.menu_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'AI',
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
