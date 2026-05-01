import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../../core/theme/theme.dart';
import '../data/social_repository.dart';
import '../models/borrow_request.dart';

/// "Borrow Requests" — the Incoming / Outgoing inbox.
///
///   * **Incoming** — rows where I'm the owner. The action surface
///     is the loud Approve / Decline pair on each pending row.
///     Approved/Denied/etc. show as read-only history.
///   * **Outgoing** — rows where I'm the borrower. Shows the live
///     status (Pending → Approved → Active → Returned) so the user
///     can track what they've asked for.
///
/// Both tabs use `AutomaticKeepAliveClientMixin` so swiping back and
/// forth doesn't refetch on every change.
class BorrowRequestsScreen extends StatefulWidget {
  const BorrowRequestsScreen({super.key});

  @override
  State<BorrowRequestsScreen> createState() => _BorrowRequestsScreenState();
}

class _BorrowRequestsScreenState extends State<BorrowRequestsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Borrow Requests',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: AppColors.background,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AppColors.accent,
              indicatorWeight: 2.5,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textTertiary,
              labelStyle: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
              tabs: const [
                Tab(text: 'INCOMING'),
                Tab(text: 'OUTGOING'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _IncomingTab(),
          _OutgoingTab(),
        ],
      ),
    );
  }
}

// ── Incoming ─────────────────────────────────────────────────

class _IncomingTab extends StatefulWidget {
  const _IncomingTab();
  @override
  State<_IncomingTab> createState() => _IncomingTabState();
}

class _IncomingTabState extends State<_IncomingTab>
    with AutomaticKeepAliveClientMixin {
  final _social = SocialRepository.instance;
  List<BorrowRequest> _rows = const [];
  bool _loading = true;

  RealtimeChannel? _liveChannel;
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final ch = _liveChannel;
    if (ch != null) AppSupabase.client.removeChannel(ch);
    super.dispose();
  }

  void _subscribeRealtime() {
    final ch = AppSupabase.client.channel(
      'borrow_incoming_${DateTime.now().millisecondsSinceEpoch}',
    );
    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'borrow_requests',
      callback: (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load();
        });
      },
    );
    ch.subscribe();
    _liveChannel = ch;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _social.fetchIncomingBorrowRequests();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _respond(BorrowRequest row, bool approve) async {
    try {
      await _social.updateBorrowStatus(
        row.id,
        approve ? BorrowStatus.approved : BorrowStatus.denied,
        expecting: BorrowStatus.pending,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Couldn\'t respond: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _markReturned(BorrowRequest row) async {
    try {
      await _social.updateBorrowStatus(
        row.id,
        BorrowStatus.returned,
        expecting: BorrowStatus.approved,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Couldn\'t mark returned: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const _EmptyTab(
                  message: 'No borrow requests waiting on you.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: _rows.length,
                  itemBuilder: (context, i) => _RequestCard(
                    row: _rows[i],
                    onMarkReturned: _markReturned,
                    perspective: _Perspective.incoming,
                    onRespond: _respond,
                  ),
                ),
    );
  }
}

// ── Outgoing ─────────────────────────────────────────────────

class _OutgoingTab extends StatefulWidget {
  const _OutgoingTab();
  @override
  State<_OutgoingTab> createState() => _OutgoingTabState();
}

class _OutgoingTabState extends State<_OutgoingTab>
    with AutomaticKeepAliveClientMixin {
  final _social = SocialRepository.instance;
  List<BorrowRequest> _rows = const [];
  bool _loading = true;

  RealtimeChannel? _liveChannel;
  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    final ch = _liveChannel;
    if (ch != null) AppSupabase.client.removeChannel(ch);
    super.dispose();
  }

  void _subscribeRealtime() {
    final ch = AppSupabase.client.channel(
      'borrow_outgoing_${DateTime.now().millisecondsSinceEpoch}',
    );
    ch.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'borrow_requests',
      callback: (_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 400), () {
          if (mounted) _load();
        });
      },
    );
    ch.subscribe();
    _liveChannel = ch;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await _social.fetchOutgoingBorrowRequests();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _cancel(BorrowRequest row) async {
    try {
      await _social.updateBorrowStatus(
        row.id,
        BorrowStatus.cancelled,
        expecting: BorrowStatus.pending,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Couldn\'t cancel: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _markReturned(BorrowRequest row) async {
    try {
      await _social.updateBorrowStatus(
        row.id,
        BorrowStatus.returned,
        expecting: BorrowStatus.approved,
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            'Couldn\'t mark returned: $e',
            style: GoogleFonts.manrope(color: Colors.white),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const _EmptyTab(
                  message: 'You haven\'t asked to borrow anything yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  itemCount: _rows.length,
                  itemBuilder: (context, i) => _RequestCard(
                    row: _rows[i],
                    perspective: _Perspective.outgoing,
                    onCancel: _cancel,
                    onMarkReturned: _markReturned,
                  ),
                ),
    );
  }
}

// ── Shared card ─────────────────────────────────────────────

enum _Perspective { incoming, outgoing }

class _RequestCard extends StatelessWidget {
  final BorrowRequest row;
  final _Perspective perspective;
  final void Function(BorrowRequest, bool approve)? onRespond;
  final void Function(BorrowRequest)? onMarkReturned;
  final void Function(BorrowRequest)? onCancel;

  const _RequestCard({
    required this.row,
    required this.perspective,
    this.onRespond,
    this.onCancel,
    this.onMarkReturned,
  });

  @override
  Widget build(BuildContext context) {
    final counter = row.counterpartyProfile;
    final preview = row.itemPreview;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: counterparty + status pill.
          Row(
            children: [
              if (preview != null && preview.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    preview.imageUrl,
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
                )
              else
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.checkroom_outlined),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      counter?.fullName ?? 'A friend',
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      perspective == _Perspective.incoming
                          ? 'wants to borrow ${preview?.category.toLowerCase() ?? "an item"}'
                          : 'borrowing ${preview?.category.toLowerCase() ?? "an item"}',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: row.status),
            ],
          ),
          const SizedBox(height: 12),

          // Window + note.
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                '${_fmt(row.borrowStart)} → ${_fmt(row.borrowEnd)}',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (row.note != null && row.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '"${row.note!.trim()}"',
                style: GoogleFonts.manrope(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ],

          // Action row: Approve/Decline (incoming) or Cancel (outgoing).
          if (row.status == BorrowStatus.pending) ...[
            const SizedBox(height: 12),
            if (perspective == _Perspective.incoming)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => onRespond?.call(row, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(
                          color: AppColors.error.withAlpha(60),
                        ),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'DECLINE',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => onRespond?.call(row, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'APPROVE',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => onCancel?.call(row),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: Text(
                    'Cancel request',
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
          ],

          // Mark Returned — only on approved rows. Either party can
          // tap; whichever side actually has the garment in hand
          // closes the loop. Once returned, the row becomes read-only
          // history.
          if (row.status == BorrowStatus.approved &&
              onMarkReturned != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => onMarkReturned!.call(row),
                icon: const Icon(
                  Icons.assignment_turned_in_outlined,
                  size: 16,
                ),
                label: Text(
                  'MARK RETURNED',
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
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

class _StatusPill extends StatelessWidget {
  final BorrowStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: GoogleFonts.manrope(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: fg,
        ),
      ),
    );
  }

  (Color, Color) _colors(BorrowStatus s) {
    switch (s) {
      case BorrowStatus.pending:
        return (AppColors.accent.withAlpha(30), AppColors.accent);
      case BorrowStatus.approved:
        return (AppColors.primary.withAlpha(30), AppColors.primary);
      case BorrowStatus.denied:
      case BorrowStatus.cancelled:
        return (AppColors.error.withAlpha(30), AppColors.error);
      case BorrowStatus.active:
        return (AppColors.primary, Colors.white);
      case BorrowStatus.returned:
        return (
          AppColors.textTertiary.withAlpha(30),
          AppColors.textSecondary,
        );
    }
  }
}

class _EmptyTab extends StatelessWidget {
  final String message;
  const _EmptyTab({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 56,
          color: AppColors.primary.withAlpha(60),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
