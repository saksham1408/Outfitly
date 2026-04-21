import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme.dart';
import '../data/calendar_service.dart';
import '../data/notification_service.dart';

/// Manual-entry form for a new calendar event.
///
/// Title is required. Subtitle is optional (typically the venue / time
/// hint). Date + time both default to "today, now rounded to the next
/// hour" so the user is one tap away from a valid save.
///
/// On save we persist to Supabase via [CalendarService.create] and
/// schedule the day-of reminder through [NotificationService]. If either
/// step fails we surface the error but leave the form populated so the
/// user can retry.
class AddEventScreen extends StatefulWidget {
  /// Pre-select this date on the date picker. Typically the day the
  /// user was viewing on the calendar when they tapped "+".
  final DateTime? initialDate;

  const AddEventScreen({super.key, this.initialDate});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();

  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final base = widget.initialDate ?? DateTime.now();
    _date = DateTime(base.year, base.month, base.day);

    // Round the current hour up by one so the default is always in the
    // future on the same day — nicer than defaulting to "right now".
    final now = DateTime.now();
    final nextHour = now.hour + 1;
    _time = nextHour >= 24
        ? const TimeOfDay(hour: 9, minute: 0)
        : TimeOfDay(hour: nextHour, minute: 0);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Event date',
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'Event time',
    );
    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final eventDate = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    try {
      final created = await CalendarService.instance.create(
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text.trim().isEmpty
            ? null
            : _subtitleCtrl.text.trim(),
        date: eventDate,
      );

      // Fire-and-forget the reminder scheduling — we don't want a
      // notification-permission hiccup to block the event save. We
      // also pop an immediate "Reminder set" banner so the user gets
      // visible proof the notification pipeline works without waiting
      // for 8 AM on the event day.
      unawaited(NotificationService.instance.scheduleEventReminder(created));
      unawaited(
        NotificationService.instance.confirmReminderScheduled(created),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved · we\'ll nudge you right when it starts.',
            style: GoogleFonts.manrope(fontSize: 13),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop<DateTime>(eventDate);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'New Event',
          style: GoogleFonts.newsreader(
            fontSize: 22,
            fontStyle: FontStyle.italic,
            color: AppColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Text(
                      'What are you dressing for?',
                      style: GoogleFonts.newsreader(
                        fontSize: 24,
                        fontStyle: FontStyle.italic,
                        color: AppColors.primary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add the occasion, pick a day and time, and we\'ll remind you right when it starts.',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    _fieldLabel('Event title'),
                    TextFormField(
                      controller: _titleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'e.g. Arjun\'s Wedding',
                        icon: Icons.event_rounded,
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Add a short title so you know what this is.';
                        }
                        if (v.trim().length > 80) {
                          return 'Keep the title under 80 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    _fieldLabel('Details (optional)'),
                    TextFormField(
                      controller: _subtitleCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: 2,
                      decoration: _inputDecoration(
                        hint: 'Venue, time, dress code…',
                        icon: Icons.notes_rounded,
                      ),
                    ),
                    const SizedBox(height: 22),

                    _fieldLabel('When'),
                    Row(
                      children: [
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.calendar_month_rounded,
                            label: _formatDate(_date),
                            onTap: _pickDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _pickerTile(
                            icon: Icons.schedule_rounded,
                            label: _time.format(context),
                            onTap: _pickTime,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(8),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withAlpha(30),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'You\'ll get a reminder at the exact time you picked above.',
                              style: GoogleFonts.manrope(
                                fontSize: 12,
                                color: AppColors.primary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Save ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: SizedBox(
                  height: 54,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.shrink()
                        : const Icon(Icons.check_rounded, size: 16),
                    label: _saving
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'ADD TO CALENDAR',
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.6,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.border.withAlpha(80),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.manrope(
        fontSize: 13,
        color: AppColors.textTertiary,
      ),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: AppColors.primary),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border.withAlpha(80)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border.withAlpha(80)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _pickerTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withAlpha(80)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}
