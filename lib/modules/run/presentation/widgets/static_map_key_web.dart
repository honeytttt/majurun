import 'package:web/web.dart' as web;

/// Web-only: extract the key from the Google Maps JS <script src="...key=..."> tag in index.html.
///
/// Uses package:web (recommended replacement for deprecated dart:html). [1](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/stats_controller.dart)[3](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/run_history.dart)
String resolveGoogleMapsApiKey({String fallback = ''}) {
  try {
    final scripts = web.document.getElementsByTagName('script'); // HTMLCollection

    for (int i = 0; i < scripts.length; i++) {
      final el = scripts.item(i);
      if (el == null) continue;

      // DOM Element API: getAttribute('src') returns the src string if present. [4](https://stackoverflow.com/questions/77175450/flutter-text-to-speech-no-sound-in-%c4%b0os)
      final src = el.getAttribute('src') ?? '';

      if (src.contains('maps.googleapis.com/maps/api/js') && src.contains('key=')) {
        final uri = Uri.tryParse(src);
        final key = uri?.queryParameters['key'];
        if (key != null && key.isNotEmpty) return key;
      }
    }
  } catch (_) {
    // ignore
  }
  return fallback;
}