import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mandate 3 — Style Pulse Chart.
///
/// "Bento box" containing a smooth, glowing area chart that
/// represents the user's "Wardrobe Utilisation" — how many
/// distinct outfit combinations they've worn / planned over
/// the last 7 days. Pink → purple gradient fills the area
/// below the curve, the curve itself is white with a soft
/// glow, and dotted grid lines stay low-contrast so the chart
/// reads as a vibe-pulse rather than a finance dashboard.
///
/// Backed by mock data today — the curve shape is intentional
/// (gentle Monday dip, weekend peak). The schema for a real
/// series would be `wardrobe_log(date, combos_count)` aggregated
/// daily; rendering doesn't change when we plug that in.
class StylePulseChart extends StatelessWidget {
  const StylePulseChart({super.key});

  // 7-day mock series — Sunday → Saturday, kept gentle.
  static const _series = <FlSpot>[
    FlSpot(0, 3),
    FlSpot(1, 2),
    FlSpot(2, 4),
    FlSpot(3, 5),
    FlSpot(4, 4),
    FlSpot(5, 6),
    FlSpot(6, 7),
  ];

  static const _dayLabels = <String>[
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 14, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A0B2E), Color(0xFF0F0A1E)],
          ),
          border: Border.all(
            color: const Color(0xFFEC4899).withAlpha(60),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEC4899).withAlpha(35),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFFEC4899),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'STYLE PULSE',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    color: const Color(0xFFEC4899),
                  ),
                ),
                const Spacer(),
                Text(
                  'Last 7 days',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: Colors.white.withAlpha(160),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Big italic headline + caption.
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Mix-and-match',
                  style: GoogleFonts.newsreader(
                    fontSize: 20,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.0,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'combos',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withAlpha(170),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 8,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withAlpha(15),
            strokeWidth: 1,
            dashArray: const [3, 3],
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _dayLabels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _dayLabels[idx],
                    style: GoogleFonts.manrope(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withAlpha(130),
                      letterSpacing: 0.6,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.black.withAlpha(220),
            getTooltipItems: (spots) {
              return spots.map((s) {
                return LineTooltipItem(
                  '${s.y.toInt()} combos',
                  GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: _series,
            isCurved: true,
            curveSmoothness: 0.32,
            color: Colors.white,
            barWidth: 2.4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) {
                // Only the peak gets a dot to keep the curve
                // clean.
                final isPeak = spot.x == 6;
                return FlDotCirclePainter(
                  radius: isPeak ? 4.5 : 0,
                  color: const Color(0xFFEC4899),
                  strokeWidth: isPeak ? 2 : 0,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFEC4899).withAlpha(150),
                  const Color(0xFFA855F7).withAlpha(90),
                  const Color(0xFFA855F7).withAlpha(0),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
    );
  }
}
