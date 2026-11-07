import 'dart:io';
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

  /// Converts a small local image file to a self-contained Base64 Data URI string
  /// if within Firestore document limits; otherwise returns the local path.
  Future<String> _fileToBase64DataUri(File file) async {
    try {
      final length = await file.length();
      if (length > 350 * 1024 || file.path.toLowerCase().endsWith('.pdf')) {
        return file.path;
      }
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      return 'data:image/jpeg;base64,$b64';
    } catch (_) {
      return file.path;
    }
  }

  /// Uploads a prescription image/PDF to private Firebase Storage (`prescriptions/{userId}/...`)
  /// if available, or falls back to compact Data URI / local path.
  Future<String> uploadPrescriptionImage({
    required String userId,
    required String localPath,
  }) async {
    if (localPath.trim().isEmpty) return '';
    final file = File(localPath);
    if (!await file.exists()) {
      return localPath;
    }

    final isPdf = localPath.toLowerCase().endsWith('.pdf');
    final ext = isPdf ? 'pdf' : 'jpg';
    final contentType = isPdf ? 'application/pdf' : 'image/jpeg';

    final st = _storageInstance;
    if (st != null) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        final ref = st
            .ref()
            .child('prescriptions')
            .child(userId)
            .child(fileName);

        final metadata = SettableMetadata(
          contentType: contentType,
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        final uploadTask = await ref
            .putFile(file, metadata)
            .timeout(const Duration(seconds: 6));
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        return downloadUrl;
      } catch (e) {
        debugPrint('StorageService: Firebase Storage fallback used.');
      }
    }

    return await _fileToBase64DataUri(file);
  }

  /// Deletes a stored prescription file from Firebase Storage or local cache.
  Future<void> deletePrescriptionFile(String storedPath) async {
    final trimmed = storedPath.trim();
    if (trimmed.isEmpty || trimmed.startsWith('data:')) return;

    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('gs://')) {
      final st = _storageInstance;
      if (st != null) {
        try {
          await st.refFromURL(trimmed).delete();
        } catch (_) {
          // Ignore if already deleted or unreachable
        }
      }
      return;
    }

    try {
      final file = File(trimmed);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Uploads a report evidence image
  Future<String> uploadReportImage({
    required String userId,
    required String localPath,
    int index = 0,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      return localPath;
    }

    final st = _storageInstance;
    if (st != null) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
        final ref = st.ref().child('reports').child(userId).child(fileName);

        final metadata = SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'userId': userId,
            'uploadedAt': DateTime.now().toIso8601String(),
          },
        );

        final uploadTask = await ref
            .putFile(file, metadata)
            .timeout(const Duration(seconds: 4));
        final downloadUrl = await uploadTask.ref.getDownloadURL();
        return downloadUrl;
      } catch (e) {
        debugPrint('StorageService: Firebase Storage fallback used.');
      }
    }

    return await _fileToBase64DataUri(file);
  }

  /// Uploads multiple report images
  Future<List<String>> uploadReportImages({
    required String userId,
    required List<String> localPaths,
  }) async {
    final List<String> urls = [];
    for (int i = 0; i < localPaths.length; i++) {
      final url = await uploadReportImage(
        userId: userId,
        localPath: localPaths[i],
        index: i,
      );
      urls.add(url);
    }
    return urls;
  }
}
