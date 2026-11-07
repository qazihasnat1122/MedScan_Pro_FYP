import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final FirebaseStorage? _storage;

  StorageService([FirebaseStorage? storage]) : _storage = storage;

  FirebaseStorage? get _storageInstance {
    if (_storage != null) return _storage;
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  /// Uploads bytes to Firebase Storage if available, or falls back to a 100% Free Base64 Data URI.
  /// This completely eliminates the requirement for a paid Firebase Blaze plan or credit card!
  Future<String> uploadBytes({
    required String path,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final st = _storageInstance;
    if (st != null) {
      try {
        final ref = st.ref().child(path);
        final metadata = SettableMetadata(
          contentType: contentType,
          customMetadata: {'uploadedAt': DateTime.now().toIso8601String()},
        );

        final uploadTask = await ref.putData(bytes, metadata).timeout(const Duration(seconds: 4));
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        return downloadUrl;
      } catch (e) {
        debugPrint('StorageService: Firebase Cloud Storage unavailable or requires Blaze plan ($e). Using zero-cost Base64 Data URI.');
      }
    }

    // Zero-Cost Free Solution: Encodes image bytes as a self-contained Data URI
    final b64 = base64Encode(bytes);
    return 'data:$contentType;base64,$b64';
  }

  /// Uploads packaging / hologram image for a medicine
  Future<String> uploadPackagingImage({
    required String medicineId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path = 'packaging/$medicineId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    return await uploadBytes(path: path, bytes: bytes);
  }
}
