import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/theme.dart';
import '../catalog/presentation/home/home_screen.dart';
import '../digital_wardrobe/presentation/daily_stylist_screen.dart';
import '../style_assistant/presentation/style_assistant_tab.dart';
import '../wardrobe_calendar/presentation/wardrobe_calendar_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  // Four root tabs. The journey now reads: browse → chat AI →
  // manage clothes → get styled. Orders moved out of the bottom
  // nav and lives behind the Profile screen's "Order History" tile
  // (route /orders) — keeping the bottom nav focused on the
  // commerce + creation loop.
  final _screens = const [
    HomeScreen(),
    StyleAssistantTab(),
    WardrobeCalendarScreen(),
    DailyStylistScreen(),
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
              children: [
                _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                _navItem(1, Icons.auto_awesome_outlined, Icons.auto_awesome,
                    'VASTRAHUB AI'),
                _navItem(2, Icons.checkroom_outlined, Icons.checkroom_rounded,
                    'Closet'),
                // "Dress Me" — the AI stylist tab. Magic-wand icon so it
                // reads as transformative/styling without clashing with
                // the auto_awesome sparkle used by VASTRAHUB AI.
                _navItem(3, Icons.auto_fix_high_outlined,
                    Icons.auto_fix_high, 'Dress Me'),
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
        // Horizontal padding shrunk to 8 (from 14) so 5 tabs still fit
        // comfortably on narrow devices — the icon + label column is
        // what centres each hit target.
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
