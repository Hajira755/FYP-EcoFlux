import 'dart:convert';
import 'dart:typed_data';

class StorageService {
  // Firestore documents max out at ~1 MiB TOTAL. A single report document
  // can hold BOTH 'imageUrl' (citizen's original photo) AND
  // 'completedImageUrl' (worker's completion photo) at the same time, so
  // the cap here must leave room for two images plus the rest of the
  // report's fields — not just one. 900 KB per image (previous value)
  // meant two images alone could reach ~1.8 MB and blow past Firestore's
  // limit, causing the write to fail exactly when a worker resolves a
  // report that already had a citizen-submitted photo.
  static const int _maxRawBytes    = 2 * 1024 * 1024;   // 2 MB raw file guard
  static const int _maxBase64Chars = 350 * 1024;        // ~350 KB encoded (per image)

  /// Base64-encodes [bytes] and returns a data-URI string like
  /// `data:image/jpeg;base64,...` that can be saved directly into a
  /// Firestore field (e.g. imageUrl / completedImageUrl / profileImageUrl).
  ///
  /// Takes raw bytes (not a dart:io File) so this works identically on
  /// Android, iOS, AND Flutter Web — dart:io File is not supported on web.
  Future<String> uploadComplaintImage(Uint8List bytes, String userId) async {
    try {
      if (bytes.length > _maxRawBytes) {
        throw Exception(
            'Image is too large (${(bytes.length / 1024 / 1024).toStringAsFixed(1)} MB). '
                'Please pick a smaller photo.');
      }

      final base64Str = base64Encode(bytes);
      final dataUri    = 'data:image/jpeg;base64,$base64Str';

      if (dataUri.length > _maxBase64Chars) {
        throw Exception(
            'Image is too large after compression. Please choose a smaller photo '
                'or reduce camera quality.');
      }

      return dataUri;
    } catch (e) {
      rethrow;
    }
  }

  /// Images now live inline inside the Firestore document, so there is no
  /// remote file to delete. Kept as a no-op so existing call sites don't
  /// need to change. Callers should just overwrite the field (set it to
  /// null/'') in Firestore if they want to "remove" the image.
  Future<void> deleteImage(String imageUrl) async {
    // no-op
  }
}