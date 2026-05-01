import 'package:flutter/foundation.dart';

/// Lifecycle states for a [FriendConnection], mirroring the
/// `status` CHECK constraint in migration 032.
enum FriendStatus {
  pending,
  accepted,
  declined,
  blocked;

  /// Round-trip the wire string. We keep these literals lowercase
  /// to match the Postgres value set; if the server ever capitalises
  /// we'll route both through the [tryParse] fallback.
  String get wire => name;

  static FriendStatus tryParse(String? raw) {
    switch (raw) {
      case 'accepted':
        return FriendStatus.accepted;
      case 'declined':
        return FriendStatus.declined;
      case 'blocked':
        return FriendStatus.blocked;
      case 'pending':
      default:
        return FriendStatus.pending;
    }
  }
}

/// One row from `public.friend_connections`.
///
/// Symmetry note: the row has a *direction* — `requesterId` sent the
/// invite to `addresseeId`. The friendship itself is symmetric once
/// `status == FriendStatus.accepted`. UI code that doesn't care about
/// direction should call [otherUserId] to get "the friend that isn't
/// me" without pattern-matching on which column they're in.
@immutable
class FriendConnection {
  final String id;
  final String requesterId;
  final String addresseeId;
  final FriendStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Joined-in profile of the *other* party for list rendering. Only
  /// populated by repository methods that explicitly ask for it via a
  /// PostgREST embed (e.g. `select('*, profiles!addressee_id(...)')`).
  /// Otherwise null — render code should null-check.
  final FriendProfile? otherProfile;

  const FriendConnection({
    required this.id,
    required this.requesterId,
    required this.addresseeId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.otherProfile,
  });

  /// Resolve the "other" user id given my id. Saves every list-render
  /// site from re-checking `auth.uid()` against both columns.
  String otherUserId(String selfId) =>
      requesterId == selfId ? addresseeId : requesterId;

  /// True iff this row is a friend request *I* received and haven't
  /// answered. Combined with [status] == pending it gates the
  /// "Approve / Decline" buttons.
  bool isIncoming(String selfId) =>
      status == FriendStatus.pending && addresseeId == selfId;

  /// True iff this is a request I sent, still awaiting their reply.
  bool isOutgoing(String selfId) =>
      status == FriendStatus.pending && requesterId == selfId;

  factory FriendConnection.fromRow(Map<String, dynamic> row) {
    // PostgREST embeds the joined profile under whichever column we
    // named in the select; we accept either of the two embed keys
    // ('addressee' or 'requester') so the same model can render both
    // incoming and outgoing rows without a branch in the caller.
    final embed = row['addressee'] ?? row['requester'] ?? row['profiles'];
    return FriendConnection(
      id: row['id'] as String,
      requesterId: row['requester_id'] as String,
      addresseeId: row['addressee_id'] as String,
      status: FriendStatus.tryParse(row['status'] as String?),
      createdAt: DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.now(),
      otherProfile: embed is Map<String, dynamic>
          ? FriendProfile.fromRow(embed)
          : null,
    );
  }
}

/// The columns of `public.profiles` we let friends read — narrow on
/// purpose so we don't lean on the RLS policy to filter sensitive
/// fields. Any new safe column (say a `bio`) goes here AND in the
/// `select(...)` string in the repository.
@immutable
class FriendProfile {
  final String id;
  final String fullName;
  final String? avatarUrl;

  const FriendProfile({
    required this.id,
    required this.fullName,
    this.avatarUrl,
  });

  /// First letter of the display name, uppercased — used as the
  /// avatar-circle fallback when [avatarUrl] is null. Plain
  /// substring is fine here: we already populated [fullName] with a
  /// non-empty trimmed value, and Flutter renders multi-byte
  /// graphemes (accents, emoji) within a single code unit slice.
  String get initial =>
      fullName.isEmpty ? '?' : fullName.substring(0, 1).toUpperCase();

  factory FriendProfile.fromRow(Map<String, dynamic> row) => FriendProfile(
        id: row['id'] as String,
        fullName: (row['full_name'] as String?)?.trim().isNotEmpty == true
            ? (row['full_name'] as String).trim()
            : 'Friend',
        avatarUrl: row['avatar_url'] as String?,
      );
}
