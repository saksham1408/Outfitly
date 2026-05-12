import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';
import '../../catalog/models/product_model.dart';
import '../models/message.dart';

/// Customer-side data layer for the Loop chat feature.
///
/// Three surfaces:
///   * [watchThreads]      — Realtime list of chat threads
///                           (one per friend). Drives the chat
///                           list screen.
///   * [watchConversation] — Realtime list of messages with
///                           a specific friend. Drives the
///                           conversation screen.
///   * [unreadCountStream] — Total unread messages count.
///                           Drives any Loop tab badge.
///
/// Mutations:
///   * [sendText]          — Plain text message.
///   * [sendOutfitShare]   — Product attachment.
///   * [markConversationAsRead] — Bulk-flip read_at for every
///                                 unread message from a given
///                                 friend.
///
/// Singleton because both the chat list and any conversation
/// screen share the same Realtime subscription. RLS scopes
/// everything to (sender_id == me OR recipient_id == me) — see
/// migration 048.
class MessagesRepository {
  MessagesRepository._() {
    _attachAuthListener();
  }
  static final MessagesRepository instance = MessagesRepository._();

  static const String _table = 'messages';

  final SupabaseClient _client = AppSupabase.client;
  // ignore: unused_field
  StreamSubscription<AuthState>? _authSub;

  /// Wipe any per-user in-memory caches when auth swaps users —
  /// belt and braces alongside the RLS policies, so a swap on
  /// the same device can never paint the previous user's
  /// messages even momentarily.
  void _attachAuthListener() {
    _authSub = _client.auth.onAuthStateChange.listen((event) {
      // Nothing local to clear right now (each screen owns its
      // own stream subscription that re-issues on rebuild), but
      // future caches plug in here.
      // ignore: avoid_print
      debugPrint('[messages] auth event: ${event.event}');
    });
  }

  // ── Streams ──────────────────────────────────────────────

  /// All messages where the calling user is sender OR recipient.
  /// Used as the source for [watchThreads] and
  /// [watchConversation] so we keep a single websocket
  /// subscription instead of one per consumer.
  Stream<List<Message>> _streamAll() {
    final me = _client.auth.currentUser?.id;
    if (me == null) {
      return const Stream<List<Message>>.empty();
    }
    return _client
        .from(_table)
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map(
          (rows) => rows
              .map(Message.fromMap)
              .where((m) => m.senderId == me || m.recipientId == me)
              .toList(growable: false),
        );
  }

  /// Per-friend chat list — newest activity first.
  ///
  /// Groups every message the user is a party to by "the other
  /// party", picks the most recent one as the preview, and
  /// counts unread inbound messages. Friend metadata (name,
  /// avatar) is hydrated from `profiles` via a follow-up
  /// SELECT — we don't join in the stream itself because
  /// supabase-flutter streams don't support .select() joins.
  Stream<List<ChatThread>> watchThreads() async* {
    final me = _client.auth.currentUser?.id;
    if (me == null) {
      yield const [];
      return;
    }

    await for (final messages in _streamAll()) {
      // Group by the other party.
      final byFriend = <String, List<Message>>{};
      for (final m in messages) {
        final otherId = m.senderId == me ? m.recipientId : m.senderId;
        byFriend.putIfAbsent(otherId, () => []).add(m);
      }
      if (byFriend.isEmpty) {
        yield const <ChatThread>[];
        continue;
      }

      // One profile fetch per stream emission. RLS scopes the
      // result; we ask for ids we already know to keep the
      // query bounded.
      final ids = byFriend.keys.toList(growable: false);
      Map<String, Map<String, dynamic>> profiles = {};
      try {
        final rows = await _client
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', ids);
        for (final row in (rows as List).cast<Map<String, dynamic>>()) {
          profiles[row['id'] as String] = row;
        }
      } catch (e) {
        debugPrint('MessagesRepository: profile hydrate failed — $e');
      }

      final threads = byFriend.entries.map((entry) {
        final friendId = entry.key;
        final convo = entry.value
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final last = convo.first;
        final unread = convo
            .where((m) => m.recipientId == me && m.isUnread)
            .length;
        final p = profiles[friendId];
        return ChatThread(
          friendId: friendId,
          friendName: (p?['full_name'] as String?)?.trim().isEmpty ?? true
              ? 'Friend'
              : (p?['full_name'] as String).trim(),
          friendAvatarUrl: p?['avatar_url'] as String?,
          lastMessage: last,
          unreadCount: unread,
        );
      }).toList()
        ..sort(
          (a, b) => b.lastMessage.createdAt.compareTo(
            a.lastMessage.createdAt,
          ),
        );

      yield threads;
    }
  }

  /// Conversation feed with a specific friend. Sorted oldest →
  /// newest so the chat UI can append-only on each emission.
  Stream<List<Message>> watchConversation(String friendId) {
    final me = _client.auth.currentUser?.id;
    if (me == null) {
      return const Stream<List<Message>>.empty();
    }
    return _streamAll().map((all) {
      return all
          .where(
            (m) =>
                (m.senderId == me && m.recipientId == friendId) ||
                (m.senderId == friendId && m.recipientId == me),
          )
          .toList(growable: false);
    });
  }

  /// Total unread messages addressed to me — drives the Loop
  /// tab badge.
  Stream<int> unreadCountStream() {
    final me = _client.auth.currentUser?.id;
    if (me == null) return Stream<int>.value(0);
    return _streamAll().map(
      (all) => all
          .where((m) => m.recipientId == me && m.isUnread)
          .length,
    );
  }

  // ── Mutations ────────────────────────────────────────────

  /// Send a plain text message to a friend.
  Future<void> sendText({
    required String recipientId,
    required String body,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;
    try {
      await _client.from(_table).insert({
        'recipient_id': recipientId,
        'body': trimmed,
      });
    } catch (e, st) {
      debugPrint('MessagesRepository.sendText failed — $e\n$st');
      rethrow;
    }
  }

  /// Send an outfit-share message — pre-composes the attachment
  /// JSON from the [ProductModel] so the conversation screen
  /// can render a preview card on the recipient's side. The
  /// optional [comment] becomes the message body (e.g. "how
  /// about this for the sangeet?").
  Future<void> sendOutfitShare({
    required String recipientId,
    required ProductModel product,
    String? comment,
  }) async {
    try {
      await _client.from(_table).insert({
        'recipient_id': recipientId,
        'body': comment?.trim().isEmpty ?? true ? null : comment!.trim(),
        'attachment': {
          'kind': 'outfit_share',
          'product_id': product.id,
          'product_name': product.name,
          // ProductModel exposes a list of images — the
          // share-preview card on the recipient's side only
          // needs the first one.
          'product_image':
              product.images.isNotEmpty ? product.images.first : null,
          'product_price': product.basePrice,
        },
      });
    } catch (e, st) {
      debugPrint('MessagesRepository.sendOutfitShare failed — $e\n$st');
      rethrow;
    }
  }

  /// Mark every unread message FROM [friendId] TO me as read.
  /// Called when the conversation screen mounts so the unread
  /// badge clears on view.
  Future<void> markConversationAsRead(String friendId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    try {
      await _client
          .from(_table)
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('sender_id', friendId)
          .eq('recipient_id', me)
          .filter('read_at', 'is', null);
    } catch (e, st) {
      debugPrint('MessagesRepository.markConversationAsRead failed — $e\n$st');
    }
  }

  /// Hard-delete a message by id. RLS lets either side of a
  /// conversation delete; the receiver sees "this message was
  /// deleted" disappear from their feed on the next stream
  /// emission.
  Future<void> deleteMessage(String messageId) async {
    try {
      await _client.from(_table).delete().eq('id', messageId);
    } catch (e, st) {
      debugPrint('MessagesRepository.deleteMessage failed — $e\n$st');
    }
  }
}
