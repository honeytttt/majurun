import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:blurhash_dart/blurhash_dart.dart';

/// Computes a compact BlurHash string (~25 chars) from image bytes so a
/// blurred preview of the *actual* photo can render instantly while the full
/// image downloads (Instagram-style blur-in).
///
/// Fully fail-safe: returns null on any error, in which case callers fall back
/// to a shimmer placeholder. Never throws, never blocks posting.
class BlurHashService {
  /// Encode [bytes] to a BlurHash string, or null if it can't be computed.
  /// Runs the CPU-heavy decode/encode in a background isolate.
  static Future<String?> encode(Uint8List bytes) async {
    try {
      return await compute(_encode, bytes);
    } catch (e) {
      debugPrint('⚠️ BlurHash encode failed: $e');
      return null;
    }
  }

  // Top-level work for compute(): pure Dart, isolate-safe.
  static String? _encode(Uint8List bytes) {
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return null;
      // BlurHash only needs a tiny image — downsample for speed.
      final small = img.copyResize(decoded, width: 32);
      return BlurHash.encode(small, numCompX: 4, numCompY: 3).hash;
    } catch (_) {
      return null;
    }
  }
}
