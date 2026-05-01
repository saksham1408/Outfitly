import 'package:flutter/foundation.dart';

import 'friend_connection.dart' show FriendProfile;

/// All states a [BorrowRequest] can be in. Mirrors the `status` CHECK
/// constraint in migration 033. Transitions:
///
///   pending ──(owner approves)──→ approved ──(today ≥ start)──→ active
///       │                              │                          │
///       ├──(owner denies)──→ denied    │                          │
///       │                              └──(borrower marks)──→ returned
///       └──(borrower withdraws)──→ cancelled
///
/// `active` and `returned` are advisory transitions surfaced by the
/// client based on the borrow window + an explicit "mark returned"
/// tap; the server doesn't enforce them since there's nothing for
/// it to verify.
enum BorrowStatus {
  pending,
  approved,
  denied,
  active,
  returned,
  cancelled;

  String get wire => name;

  /// Human label for the status pill. Keeping it on the enum (vs in
  /// the widget) means future surfaces can render the same string
  /// without copying the switch.
  String get label {
    switch (this) {
      case BorrowStatus.pending:
        return 'Pending';
      case BorrowStatus.approved:
        return 'Approved';
      case BorrowStatus.denied:
        return 'Denied';
      case BorrowStatus.active:
        return 'Active';
      case BorrowStatus.returned:
        return 'Returned';
      case BorrowStatus.cancelled:
        return 'Cancelled';
    }
  }

  static BorrowStatus tryParse(String? raw) {
    switch (raw) {
      case 'approved':
        return BorrowStatus.approved;
      case 'denied':
        return BorrowStatus.denied;
      case 'active':
        return BorrowStatus.active;
      case 'returned':
        return BorrowStatus.returned;
      case 'cancelled':
        return BorrowStatus.cancelled;
      case 'pending':
      default:
        return BorrowStatus.pending;
    }
  }
}

/// One row from `public.borrow_requests`.
///
/// The model carries optional [counterpartyProfile] (the *other*
/// party in the loan — owner if I'm the borrower, borrower if I'm
/// the owner) and optional [itemPreview] (the wardrobe row's image
/// + category) so list screens can render in a single fetch via a
/// PostgREST embed without N+1 round trips.
@immutable
class BorrowRequest {
  final String id;
  final String borrowerId;
  final String ownerId;
  final String wardrobeItemId;
  final BorrowStatus status;
  final DateTime borrowStart;
  final DateTime borrowEnd;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Joined profile of the *other* party. Populated by repository
  /// methods that include `profiles` in the select.
  final FriendProfile? counterpartyProfile;

  /// Joined snapshot of the wardrobe item — just enough fields to
  /// render the request card (image, category). Null if not embedded.
  final BorrowItemPreview? itemPreview;

  const BorrowRequest({
    required this.id,
    required this.borrowerId,
    required this.ownerId,
    required this.wardrobeItemId,
    required this.status,
    required this.borrowStart,
    required this.borrowEnd,
    required this.createdAt,
    required this.updatedAt,
    this.note,
    this.counterpartyProfile,
    this.itemPreview,
  });

  /// True if I'm the owner being asked to approve. Compose with
  /// [status] to gate the action buttons.
  bool isIncoming(String selfId) => ownerId == selfId;

  /// True if I'm the borrower waiting on a response.
  bool isOutgoing(String selfId) => borrowerId == selfId;

  /// Insert payload — server fills `id`, `created_at`, `updated_at`,
  /// and (via the column default) `borrower_id`. We send `owner_id`
  /// explicitly because the server won't infer it from the item id.
  Map<String, dynamic> toInsertRow() => {
        'owner_id': ownerId,
        'wardrobe_item_id': wardrobeItemId,
        'borrow_start': borrowStart.toIso8601String().substring(0, 10),
        'borrow_end': borrowEnd.toIso8601String().substring(0, 10),
        if (note != null && note!.trim().isNotEmpty) 'note': note!.trim(),
      };

  factory BorrowRequest.fromRow(Map<String, dynamic> row) {
    // PostgREST embeds appear under whatever alias the select used;
    // we accept the common variants so list and detail queries can
    // share this constructor.
    final ownerEmbed = row['owner'] ?? row['owner_profile'];
    final borrowerEmbed = row['borrower'] ?? row['borrower_profile'];
    final itemEmbed = row['wardrobe_item'] ?? row['item'];

    // Pick whichever counterparty was embedded — caller picks based
    // on the perspective of the screen (incoming list embeds the
    // borrower; outgoing list embeds the owner).
    final counter = ownerEmbed ?? borrowerEmbed;

    return BorrowRequest(
      id: row['id'] as String,
      borrowerId: row['borrower_id'] as String,
      ownerId: row['owner_id'] as String,
      wardrobeItemId: row['wardrobe_item_id'] as String,
      status: BorrowStatus.tryParse(row['status'] as String?),
      borrowStart: DateTime.tryParse(row['borrow_start'] as String? ?? '') ??
          DateTime.now(),
      borrowEnd: DateTime.tryParse(row['borrow_end'] as String? ?? '') ??
          DateTime.now(),
      note: row['note'] as String?,
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.now(),
      counterpartyProfile: counter is Map<String, dynamic>
          ? FriendProfile.fromRow(counter)
          : null,
      itemPreview: itemEmbed is Map<String, dynamic>
          ? BorrowItemPreview.fromRow(itemEmbed)
          : null,
    );
  }
}

/// Tiny projection of `public.wardrobe_items` for embedding in a
/// borrow-request list. We deliberately don't reuse `WardrobeItem`
/// here — it's the *owner's* row, and its full shape (with `userId`,
/// `isShareable`) isn't relevant to the requesting flow's UI.
@immutable
class BorrowItemPreview {
  final String id;
  final String imageUrl;
  final String category;

  const BorrowItemPreview({
    required this.id,
    required this.imageUrl,
    required this.category,
  });

  factory BorrowItemPreview.fromRow(Map<String, dynamic> row) =>
      BorrowItemPreview(
        id: row['id'] as String,
        imageUrl: (row['image_url'] as String?) ?? '',
        category: (row['category'] as String?) ?? '',
      );
}
