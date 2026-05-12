import 'package:flutter/foundation.dart';

/// What kind of payload a message carries. Matches the
/// `attachment.kind` discriminator on `public.messages`.
enum MessageKind {
  /// Plain text — `body` populated, no attachment.
  text,

  /// Outfit share — `attachment` carries a product the sender
  /// picked from the catalog. `body` may be a comment ("how
  /// about this for the sangeet?") or empty.
  outfitShare,
}

/// One row from `public.messages`.
///
/// Single class for both flavours. The presentation layer
/// branches on [kind] to render a chat bubble vs an outfit
/// preview card.
@immutable
class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
    this.body,
    this.attachment,
    this.readAt,
  });

  final String id;
  final String senderId;
  final String recipientId;
  final String? body;
  final Map<String, dynamic>? attachment;
  final DateTime? readAt;
  final DateTime createdAt;

  /// True until the recipient opens the conversation that
  /// contains this row.
  bool get isUnread => readAt == null;

  /// Picks the right rendering bucket. Outfit shares win when
  /// the attachment is present, regardless of body — the comment
  /// (if any) renders inside the same bubble as the preview card.
  MessageKind get kind {
    if (attachment != null &&
        (attachment!['kind'] as String?) == 'outfit_share') {
      return MessageKind.outfitShare;
    }
    return MessageKind.text;
  }

  /// Convenience accessor for outfit-share previews. Returns
  /// null when this isn't an outfit share.
  ({
    String productId,
    String productName,
    String? productImage,
    double? productPrice,
  })? get outfitShare {
    if (kind != MessageKind.outfitShare) return null;
    final a = attachment!;
    return (
      productId: (a['product_id'] as String?) ?? '',
      productName: (a['product_name'] as String?) ?? 'Shared piece',
      productImage: a['product_image'] as String?,
      productPrice: (a['product_price'] as num?)?.toDouble(),
    );
  }

  /// True if this row was sent by the calling user. Used to
  /// flip bubble alignment + colour in the conversation UI.
  bool isMine(String myUid) => senderId == myUid;

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String,
      body: (map['body'] as String?)?.trim().isEmpty ?? true
          ? null
          : (map['body'] as String).trim(),
      attachment: map['attachment'] is Map<String, dynamic>
          ? map['attachment'] as Map<String, dynamic>
          : null,
      readAt:
          DateTime.tryParse(map['read_at'] as String? ?? '')?.toLocal(),
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}

/// Roll-up shown on the chat-list screen — one row per friend
/// the calling user has exchanged messages with. Built
/// client-side from a stream of all messages by grouping by
/// "the other party" and picking the latest row + the unread
/// count.
@immutable
class ChatThread {
  const ChatThread({
    required this.friendId,
    required this.friendName,
    required this.friendAvatarUrl,
    required this.lastMessage,
    required this.unreadCount,
  });

  final String friendId;
  final String friendName;
  final String? friendAvatarUrl;
  final Message lastMessage;
  final int unreadCount;
}
