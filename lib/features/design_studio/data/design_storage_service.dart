import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/supabase_client.dart';

/// Handles uploading user-generated custom design references to
/// Supabase Storage (bucket: `custom_designs`) and returning a public
/// URL that can be stamped onto an order.
class DesignStorageService {
  static const String bucket = 'custom_designs';

  final _client = AppSupabase.client;
  final _picker = ImagePicker();

  /// Opens the device gallery and returns the picked image, or `null`
  /// if the user cancelled. Images are downscaled and compressed to
  /// keep uploads fast over mobile networks.
  Future<XFile?> pickFromGallery() {
    return _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2048,
    );
  }

  /// Uploads [file] to the `custom_designs` bucket under the current
  /// user's folder and returns the public URL. Throws if the user is
  /// unauthenticated or if the upload fails.
  Future<String> uploadCustomDesign(XFile file) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to upload custom designs.');
    }

    final ext = _extractExtension(file.name);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    // Scope uploads under the user id so Storage RLS policies can
    // key authorization off auth.uid().
    final path = '${user.id}/$timestamp.$ext';

    final storage = _client.storage.from(bucket);
    final bytes = await file.readAsBytes();

    await storage.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: _mimeFor(ext),
        upsert: false,
      ),
    );

    return storage.getPublicUrl(path);
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
