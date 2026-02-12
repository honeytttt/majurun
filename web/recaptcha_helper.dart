// recaptcha_helper.dart (web-only – use conditional import if needed)
import 'dart:js' as js;

Future<String?> getRecaptchaToken(String action) async {
  try {
    final promise = js.context.callMethod('grecaptcha.enterprise.execute', [
      '6LfJE2gsAAAAAP2xeAzsC95tz7jAzim7wAjtarF0',  // YOUR SITE KEY
      js.JsObject.jsify({'action': action}),
    ]);
    final token = await js.promiseToFuture<String>(promise);
    return token;
  } catch (e) {
    print('reCAPTCHA error: $e');
    return null;
  }
}