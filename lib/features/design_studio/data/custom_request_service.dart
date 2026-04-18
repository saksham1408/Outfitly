import 'package:image_picker/image_picker.dart';

import '../../../core/network/supabase_client.dart';
import 'design_storage_service.dart';

/// Persists a bespoke embroidery request — image + base garment + notes —
/// to the `custom_requests` table so the atelier can review it from
/// Directus.
class CustomRequestService {
  final _client = AppSupabase.client;
  final DesignStorageService _storage = DesignStorageService();

  /// Submits a custom embroidery request. Uploads [image] to Supabase
  /// Storage, then writes a row into `custom_requests`.
  ///
  /// Returns the inserted row id on success.
  Future<String> submit({
    required XFile image,
    required String baseGarment,
    required String notes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to submit a custom request.');
    }

    // 1. Upload the image — reuses the same bucket as the Design Studio.
    final imageUrl = await _storage.uploadCustomDesign(image);

    // 2. Insert the request row.
    final inserted = await _client
        .from('custom_requests')
        .insert({
          'user_id': user.id,
          'image_url': imageUrl,
          'base_garment': baseGarment,
          'custom_notes': notes,
          'status': 'pending_review',
        })
        .select('id')
        .single();

    return inserted['id'] as String;
  }
}
