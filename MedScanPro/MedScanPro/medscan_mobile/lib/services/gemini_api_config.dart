import 'dart:async';
import 'package:flutter/services.dart';

/// Centralized, unified Gemini API key provider shared across all MedScan Pro modules:
/// - Prescription AI (`prescription_ai_service.dart`)
/// - AI Chatbot (`ai_rag_service.dart` / `ai_chat_screen.dart`)
/// - Nearby Pharmacies (`gemini_maps_pharmacy_service.dart`)
///
/// Resolution hierarchy:
/// 1. Dynamic in-memory key override (set via AI Chat screen dialog or tests)
/// 2. Compile-time `--dart-define=GEMINI_API_KEY=...` (or `--dart-define-from-file=.env`)
/// 3. Cached native Android secret (preventing duplicate MethodChannel invocations)
/// 4. Native MethodChannel `com.medscan.pro/document_picker` -> `getDevApiKey`
///    (reads `R.string.medscan_dev_gemini_key` populated by Gradle from root `.env`)
class GeminiApiKeyProvider {
  static const MethodChannel _platformChannel = MethodChannel(
    'com.medscan.pro/document_picker',
  );

  /// Compile-time `--dart-define=GEMINI_API_KEY=...`
  static const String _compileTimeKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  static String? _cachedKey;
  static String? _overrideKey;

  /// Returns the current synchronous key without performing asynchronous lookups.
  /// Returns in order: explicit runtime override -> compile-time define -> cached native key -> empty string.
  static String get currentKey {
    if (_overrideKey != null) return _overrideKey!;
    if (_compileTimeKey.trim().isNotEmpty) return _compileTimeKey.trim();
    if (_cachedKey != null && _cachedKey!.isNotEmpty) return _cachedKey!;
    return '';
  }

  /// Resolves the active Gemini API key asynchronously.
  /// Lookups to native Android method channel are performed at most once and cached for the process lifetime.
  static Future<String> resolveApiKey() async {
    // 1. Explicit runtime override takes highest priority (including explicitly disabled '')
    if (_overrideKey != null) {
      return _overrideKey!;
    }

    // 2. Compile-time environment variable (--dart-define=GEMINI_API_KEY=...)
    if (_compileTimeKey.trim().isNotEmpty) {
      return _compileTimeKey.trim();
    }

    // 3. Return cached key if already resolved from native channel
    if (_cachedKey != null && _cachedKey!.isNotEmpty) {
      return _cachedKey!;
    }

    // 4. Fallback to native Android method channel injected from .env via Gradle
    try {
      final nativeKey = await _platformChannel
          .invokeMethod<String>('getDevApiKey')
          .timeout(const Duration(milliseconds: 300));
      _cachedKey = (nativeKey ?? '').trim();
      return _cachedKey!;
    } catch (_) {
      _cachedKey = '';
      return '';
    }
  }

  /// Explicitly sets or overrides the active Gemini API key at runtime.
  static void setApiKey(String key) {
    _overrideKey = key.trim();
  }

  /// Clears in-memory override and cached state (for unit testing).
  static void resetForTesting() {
    _overrideKey = null;
    _cachedKey = null;
  }
}
