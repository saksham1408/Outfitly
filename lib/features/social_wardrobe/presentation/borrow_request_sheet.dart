import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../../digital_wardrobe/data/wardrobe_repository.dart';
import '../../digital_wardrobe/models/wardrobe_item.dart';
import '../models/borrow_request.dart';

/// Modal bottom sheet that captures the borrow window + an optional
/// note, then fires `WardrobeRepository.sendBorrowRequest`.
///
/// Inputs: the [item] being asked for, plus the [ownerId] (carried
/// separately because some catalog projections drop `userId` on the
/// item model — passing it explicitly keeps this sheet decoupled).
///
/// Pop result:
///   * The persisted [BorrowRequest] on success.
///   * `null` if the user dismissed.
Future<BorrowRequest?> showBorrowRequestSheet(
  BuildContext context, {
  required WardrobeItem item,
  required String ownerId,
  required String ownerFirstName,
}) {
  return showModalBottomSheet<BorrowRequest?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BorrowRequestSheet(
      item: item,
      ownerId: ownerId,
      ownerFirstName: ownerFirstName,
    ),
  );
}

class _BorrowRequestSheet extends StatefulWidget {
  const _BorrowRequestSheet({
    required this.item,
    required this.ownerId,
    required this.ownerFirstName,
  });

  final WardrobeItem item;
  final String ownerId;
  final String ownerFirstName;

  @override
  State<_BorrowRequestSheet> createState() => _BorrowRequestSheetState();
}

class _BorrowRequestSheetState extends State<_BorrowRequestSheet> {
  /// Default to a 2-day borrow starting tomorrow — covers the most
  /// common case ("borrow this for the weekend wedding") and gives
  /// the owner time to physically hand it over.
  late DateTime _start = DateTime.now().add(const Duration(days: 1));
  late DateTime _end = DateTime.now().add(const Duration(days: 3));

  final _noteController = TextEditingController();

  bool _sending = false;
  String? _error;

  Future<void> _pickRange() async {
    final today = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _start, end: _end),
      firstDate: today,
      // 6-month forward window — anything longer than that probably
      // wants a different feature ("borrow indefinitely") rather than
      // a single-tap request.
      lastDate: today.add(const Duration(days: 180)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null) return;
    setState(() {
      _start = picked.start;
      _end = picked.end;
    });
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    // borrower_id is filled server-side via DEFAULT auth.uid(); the
    // local model just needs *something* — the saved row that comes
    // back from `.select().single()` carries the canonical id.
    final selfId = AppSupabase.client.auth.currentUser?.id ?? '';
    final draft = BorrowRequest(
      id: 'pending',
      borrowerId: selfId,
      ownerId: widget.ownerId,
      wardrobeItemId: widget.item.id,
      status: BorrowStatus.pending,
      borrowStart: _start,
      borrowEnd: _end,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    try {
      final saved =
          await WardrobeRepository.instance.sendBorrowRequest(draft);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn\'t send: $e';
        _sending = false;
      });
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle.
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title + item snapshot.
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    widget.item.imageUrl,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      color: AppColors.background,
                      child: const Icon(Icons.image_outlined, size: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Borrow ${widget.item.category.toLowerCase()}',
                        style: GoogleFonts.newsreader(
                          fontSize: 22,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'from ${widget.ownerFirstName}',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(
              'BORROW WINDOW',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickRange,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(30)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_fmt(_start)} → ${_fmt(_end)}'
                        '   (${_end.difference(_start).inDays + 1} days)',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.edit_calendar_outlined,
                      size: 16,
                      color: AppColors.primary.withAlpha(180),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'NOTE (OPTIONAL)',
              style: GoogleFonts.manrope(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLength: 280,
              maxLines: 3,
              minLines: 2,
              style: GoogleFonts.manrope(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText:
                    'Hey! Borrowing this for the weekend wedding — promise to return Monday morning.',
                hintStyle: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: AppColors.error,
                ),
              ),
            ],
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'SEND BORROW REQUEST',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _fmt(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month - 1]}';
  }
}
