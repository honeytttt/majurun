import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Builds circular avatar BitmapDescriptors for Google Maps markers.
/// Used on active run, last activity, and run detail screens.
class MapMarkerBuilder {
  static const double _sz = 96;
  static const double _cx = _sz / 2;
  static const double _border = 4;
  static const double _imgR = _cx - _border - 1;

  /// Fetches the current user's photo from Firestore and builds a marker.
  /// Returns null if no user is logged in.
  static Future<BitmapDescriptor?> buildForCurrentUser({
    Color borderColor = const Color(0xFF7ED957),
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return buildForUser(uid, borderColor: borderColor);
  }

  /// Fetches any user's photo from Firestore by uid and builds a marker.
  static Future<BitmapDescriptor> buildForUser(
    String uid, {
    Color borderColor = const Color(0xFF7ED957),
  }) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      final photoUrl = doc.data()?['photoUrl'] as String? ?? '';
      return build(photoUrl, borderColor: borderColor);
    } catch (_) {
      return build('', borderColor: borderColor);
    }
  }

  /// Builds an avatar marker from a photo URL with a colored border ring.
  static Future<BitmapDescriptor> build(
    String photoUrl, {
    Color borderColor = const Color(0xFF7ED957),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, _sz, _sz));

    // Outer border ring
    canvas.drawCircle(
      const Offset(_cx, _cx),
      _cx - 1,
      Paint()..color = borderColor,
    );

    bool drawn = false;
    if (photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
      try {
        final resp = await http
            .get(Uri.parse(photoUrl))
            .timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(
            resp.bodyBytes,
            targetWidth: (_imgR * 2).round(),
            targetHeight: (_imgR * 2).round(),
          );
          final frame = await codec.getNextFrame();
          canvas.save();
          canvas.clipPath(
            Path()
              ..addOval(Rect.fromCircle(
                center: const Offset(_cx, _cx),
                radius: _imgR,
              )),
          );
          canvas.drawImageRect(
            frame.image,
            Rect.fromLTWH(0, 0, frame.image.width.toDouble(),
                frame.image.height.toDouble()),
            Rect.fromCircle(center: const Offset(_cx, _cx), radius: _imgR),
            Paint(),
          );
          canvas.restore();
          drawn = true;
        }
      } catch (e) {
        debugPrint('⚠️ MapMarkerBuilder: avatar draw failed, using fallback silhouette: $e');
      }
    }

    if (!drawn) {
      // Fallback: silhouette
      canvas.drawCircle(
        const Offset(_cx, _cx),
        _imgR,
        Paint()..color = const Color(0xFF1B4D2C),
      );
      final p = Paint()..color = Colors.white;
      canvas.drawCircle(const Offset(_cx, _cx - 12), 10, p);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: const Offset(_cx, _cx + 10), width: 24, height: 18),
          const Radius.circular(8),
        ),
        p,
      );
    }

    final img = await recorder
        .endRecording()
        .toImage(_sz.round(), _sz.round());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }
}
