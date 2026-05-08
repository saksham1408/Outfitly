import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/supabase_client.dart';
import '../models/custom_stitch_order.dart';

/// Supabase-backed store for the "Stitch My Fabric" feature.
///
/// Two responsibilities:
///   1. [bookPickup] — INSERT a new `custom_stitch_orders` row.
///      Optionally uploads a reference-design image to the
///      `custom_stitch_refs` Storage bucket and stamps the public
///      URL onto the row.
///   2. [fetchUserCustomOrders] — SELECT every booking belonging
///      to the calling user, newest first. Backed by RLS, so the
///      filter is server-side only — the client just asks "give me
///      mine" and Postgres enforces it.
///
/// Singleton because the dashboard, the booking screen, and any
/// future Realtime watcher share the same in-memory cache via
/// [orders] (a [ValueNotifier]) — same pattern the rest of the
/// repositories in this codebase use (see [WardrobeRepository]).
class CustomStitchingRepository {
  CustomStitchingRepository._();
  static final CustomStitchingRepository instance =
      CustomStitchingRepository._();

  static const String _table = 'custom_stitch_orders';
  static const String _bucket = 'custom_stitch_refs';

  final SupabaseClient _client = AppSupabase.client;

  final ValueNotifier<List<CustomStitchOrder>> _orders =
      ValueNotifier<List<CustomStitchOrder>>(const <CustomStitchOrder>[]);

  /// Live list of the calling user's bookings. The dashboard binds
  /// to this via a [ValueListenableBuilder] so it rebuilds the
  /// instant a new booking is inserted.
  ValueListenable<List<CustomStitchOrder>> get orders => _orders;

  /// Force a fresh read from Supabase. The dashboard pulls this
  /// on mount and on pull-to-refresh.
  ///
  /// On transient errors we keep whatever list we already have —
  /// blanking the dashboard on a flaky connection feels broken.
  Future<List<CustomStitchOrder>> fetchUserCustomOrders() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _orders.value = const [];
      return const [];
    }

    try {
      final rows = await _client
          .from(_table)
          .select()
          .order('created_at', ascending: false);

      final list = (rows as List)
          .cast<Map<String, dynamic>>()
          .map(CustomStitchOrder.fromRow)
          .toList(growable: false);
      _orders.value = list;
      return list;
    } catch (e, st) {
      debugPrint(
        'CustomStitchingRepository.fetchUserCustomOrders failed — $e\n$st',
      );
      return _orders.value;
    }
  }

  /// Insert a new booking. If [referenceImage] is provided we
  /// upload it to the `custom_stitch_refs` bucket first, then
  /// stamp its public URL onto the row before inserting.
  ///
  /// Returns the persisted [CustomStitchOrder] (with the
  /// server-issued id and timestamps) so the caller can splice it
  /// into the cache without a refetch.
  Future<CustomStitchOrder> bookPickup(
    CustomStitchOrder order, {
    File? referenceImage,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to book a pickup.');
    }

    String? uploadedUrl = order.referenceImageUrl;
    String? uploadedPath;

    if (referenceImage != null) {
      final upload = await _uploadReferenceImage(
        userId: user.id,
        file: referenceImage,
      );
      uploadedUrl = upload.publicUrl;
      uploadedPath = upload.storagePath;
    }

    // Build the actual insert payload — overlay the resolved URL
    // on top of whatever the caller set so we don't accidentally
    // double-store the image.
    final payload = order
        .copyWith(referenceImageUrl: uploadedUrl)
        .toInsertRow();

    Map<String, dynamic> inserted;
    try {
      inserted = await _client
          .from(_table)
          .insert(payload)
          .select()
          .single();
    } catch (e) {
      // Roll back the storage object so a row that never
      // committed doesn't leave an orphaned binary.
      if (uploadedPath != null) {
        try {
          await _client.storage.from(_bucket).remove([uploadedPath]);
        } catch (_) {/* best-effort cleanup */}
      }
      rethrow;
    }

    final saved = CustomStitchOrder.fromRow(inserted);

    // Splice into the cache so the dashboard's
    // ValueListenableBuilder rebuilds without an extra round-trip.
    _orders.value = <CustomStitchOrder>[saved, ..._orders.value];
    return saved;
  }

  // ── helpers ─────────────────────────────────────────────────

  Future<({String publicUrl, String storagePath})> _uploadReferenceImage({
    required String userId,
    required File file,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = _extractExtension(file.path);
    final id = const Uuid().v4();
    // First path segment must be the uid so the Storage RLS
    // policy `custom_stitch_refs_own_insert` passes.
    final storagePath = '$userId/$id.$ext';

    final storage = _client.storage.from(_bucket);

    await storage.uploadBinary(
      storagePath,
      bytes,
      fileOptions: FileOptions(
        contentType: _mimeFor(ext),
        upsert: false,
      ),
    );

    return (
      publicUrl: storage.getPublicUrl(storagePath),
      storagePath: storagePath,
    );
  }

  String _extractExtension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot == -1 || dot == fileName.length - 1) return 'jpg';
    return fileName.substring(dot + 1).toLowerCase();
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
