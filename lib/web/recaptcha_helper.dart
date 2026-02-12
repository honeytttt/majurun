// lib/web/recaptcha_helper.dart
// Web-only file — suppress unavoidable lints

// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:js_interop';
import 'package:flutter/foundation.dart' show debugPrint;

@JS('grecaptcha.enterprise.execute')
external JSPromise<JSString> _execute(JSString siteKey, JSObject options);

Future<String?> getRecaptchaToken(String action) async {
  try {
    final promise = _execute(
      '6LfJE2gsAAAAAP2xeAzsC95tz7jAzim7wAjtarF0'.toJS,
      {'action': action}.jsify() as JSObject,
    );

    final jsToken = await promise.toDart;
    return jsToken.toDart;  // JSString.toDart returns String
  } catch (e) {
    debugPrint('reCAPTCHA execute failed: $e');
    return null;
  }
}