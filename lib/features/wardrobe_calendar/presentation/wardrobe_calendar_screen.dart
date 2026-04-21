import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/theme.dart';
import '../data/calendar_service.dart';
import '../domain/planner_event.dart';
import '../domain/wardrobe_item.dart';

/// Main tab destination for the Wardrobe Planner.
///
/// Top half  : [TableCalendar] month grid with highlighted days that
///             have at least one [PlannerEvent].
/// Bottom half: Details for the currently selected day — either the
///             "nothing planned" empty state or a stack of event cards
///             with a CTA that opens the Mix-and-Match planner.
///
/// A secondary link at the top jumps into the digital closet.
class WardrobeCalendarScreen extends StatefulWidget {
  const WardrobeCalendarScreen({super.key});

  @override
  State<WardrobeCalendarScreen> createState() =>
      _WardrobeCalendarScreenState();
}

class _WardrobeCalendarScreenState extends State<WardrobeCalendarScreen> {
  final _service = CalendarService.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;

  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      await _service.fetchAll();
    } catch (e) {
      _loadError = 'Could not load your events. Pull to retry.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openAddEvent() async {
    final created = await context.push<DateTime>(
      '/wardrobe/add-event',
      extra: _selectedDay,
    );
    if (created != null && mounted) {
      // Jump the grid to the newly added event so the user sees their
      // entry rendered on the right day without hunting for it.
      setState(() {
        _selectedDay = DateTime(created.year, created.month, created.day);
        _focusedDay = _selectedDay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: _openAddEvent,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'NEW EVENT',
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
          ),
        ),
      ),
      body: SafeArea(
        child: ValueListenableBuilder<List<PlannerEvent>>(
          valueListenable: _service.events,
          builder: (context, events, _) {
            final selectedEvents = events
                .where((e) => isSameDay(e.date, _selectedDay))
                .toList();

            return Column(
              children: [
                // ── Header ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Wardrobe Planner',
                              style: GoogleFonts.newsreader(
                                fontSize: 26,
                                fontStyle: FontStyle.italic,
                                color: AppColors.primary,
                                height: 1.1,
                              ),
                            ),
                            Container(
                              height: 2,
                              width: 44,
                              margin: const EdgeInsets.only(top: 4),
                              color: AppColors.accent,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Your days, pre-styled.',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/wardrobe'),
                        icon: const Icon(
                          Icons.checkroom_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          'My Closet',
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Calendar ──
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border.withAlpha(60)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(6),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TableCalendar<PlannerEvent>(
                    firstDay: DateTime.now()
                        .subtract(const Duration(days: 365)),
                    lastDay:
                        DateTime.now().add(const Duration(days: 365)),
                    focusedDay: _focusedDay,
                    calendarFormat: _format,
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    availableCalendarFormats: const {
                      CalendarFormat.month: 'Month',
                      CalendarFormat.twoWeeks: '2 weeks',
                      CalendarFormat.week: 'Week',
                    },
                    selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                    eventLoader: (d) =>
                        events.where((e) => isSameDay(e.date, d)).toList(),
                    onDaySelected: (selected, focused) {
                      setState(() {
                        _selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                    onFormatChanged: (f) => setState(() => _format = f),
                    onPageChanged: (focused) => _focusedDay = focused,
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonShowsNext: false,
                      titleTextStyle: GoogleFonts.newsreader(
                        fontSize: 18,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primary,
                      ),
                      formatButtonTextStyle: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                      formatButtonDecoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      leftChevronIcon: const Icon(Icons.chevron_left_rounded,
                          color: AppColors.primary),
                      rightChevronIcon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary),
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 1,
                      ),
                      weekendStyle: GoogleFonts.manrope(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                        letterSpacing: 1,
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      todayDecoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(22),
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: GoogleFonts.manrope(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      selectedDecoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: GoogleFonts.manrope(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      defaultTextStyle: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      weekendTextStyle: GoogleFonts.manrope(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      markersMaxCount: 1,
                      markerDecoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                      markerMargin:
                          const EdgeInsets.symmetric(horizontal: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Event details ──
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppColors.primary,
                    child: _loading && events.isEmpty
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : _loadError != null && events.isEmpty
                            ? _ErrorState(
                                message: _loadError!,
                                onRetry: _refresh,
                              )
                            : selectedEvents.isEmpty
                                ? ListView(
                                    // Always-scrollable keeps pull-to-refresh
                                    // responsive even on an empty day.
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    children: [
                                      SizedBox(
                                        height: MediaQuery.of(context)
                                                .size
                                                .height *
                                            0.3,
                                        child: _EmptyDay(
                                          date: _selectedDay,
                                          onAdd: _openAddEvent,
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 4, 16, 96),
                                    itemCount: selectedEvents.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (_, i) =>
                                        _EventCard(event: selectedEvents[i]),
                                  ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  final DateTime date;
  final VoidCallback? onAdd;
  const _EmptyDay({required this.date, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_rounded,
              size: 48,
              color: AppColors.textTertiary.withAlpha(80),
            ),
            const SizedBox(height: 12),
            Text(
              'Nothing on ${_formatDate(date)}',
              style: GoogleFonts.newsreader(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "New event" to plan a look for this day.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: AppColors.textTertiary,
                height: 1.5,
              ),
            ),
            if (onAdd != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Add event',
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 40,
                    color: AppColors.textTertiary.withAlpha(120),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Retry',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

/// Visual card for a single event on the selected day. If an outfit has
/// already been assigned we show tiny thumbnails; otherwise the CTA is
/// the dominant element so the user knows the next action.
class _EventCard extends StatelessWidget {
  final PlannerEvent event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final outfit = event.assignedOutfit;
    final isPlanned = outfit != null && !outfit.isEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: isPlanned
              ? const [AppColors.primaryDark, AppColors.primary]
              : [AppColors.surface, AppColors.surfaceContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isPlanned
              ? AppColors.primary
              : AppColors.border.withAlpha(80),
        ),
        boxShadow: [
          BoxShadow(
            color: isPlanned
                ? AppColors.primary.withAlpha(50)
                : Colors.black.withAlpha(6),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPlanned
                      ? Colors.white.withAlpha(28)
                      : AppColors.primary.withAlpha(12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.event_rounded,
                  color: isPlanned ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: GoogleFonts.newsreader(
                        fontSize: 20,
                        fontStyle: FontStyle.italic,
                        color: isPlanned
                            ? Colors.white
                            : AppColors.primary,
                      ),
                    ),
                    if (event.subtitle != null)
                      Text(
                        event.subtitle!,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: isPlanned
                              ? Colors.white.withAlpha(200)
                              : AppColors.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
              if (isPlanned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'PLANNED',
                    style: GoogleFonts.manrope(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
            ],
          ),

          // Outfit preview — small thumbs inline when planned
          if (isPlanned) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 64,
              child: Row(
                children: _preview(outfit).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _thumb(item),
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => context.push(
                '/wardrobe/planner',
                extra: event,
              ),
              icon: Icon(
                isPlanned
                    ? Icons.edit_rounded
                    : Icons.auto_awesome_rounded,
                size: 16,
              ),
              label: Text(
                isPlanned ? 'Edit outfit' : 'Plan Outfit for this Event',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPlanned
                    ? AppColors.accentContainer
                    : AppColors.primary,
                foregroundColor:
                    isPlanned ? AppColors.primaryDark : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<WardrobeItem> _preview(PlannedOutfit o) {
    return [
      if (o.top != null) o.top!,
      if (o.bottom != null) o.bottom!,
      if (o.footwear != null) o.footwear!,
      if (o.accessory != null) o.accessory!,
    ];
  }

  Widget _thumb(WardrobeItem item) {
    return Container(
      width: 56,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withAlpha(60)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        item.imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Container(color: AppColors.surfaceContainer),
      ),
    );
  }
}
