import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Web avatar via HtmlElementView.fromTagName + package:web (no dart:html).
/// package:web is the recommended replacement for deprecated dart:html. [3](https://github.com/flutter/flutter/issues/79647)[5](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/follow_service.dart)[6](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/profile_settings_screen.dart)
/// HtmlElementView is the documented way to embed HTML elements in Flutter web. [4](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/home_screen.dart)[7](https://necms-my.sharepoint.com/personal/hanumaiah_ta_nec_com_sg/Documents/Microsoft%20Copilot%20Chat%20Files/profile_screen.dart)
Widget buildUserAvatar({required String photoUrl, required double radius}) {
  final url = photoUrl.trim();
  final size = radius * 2;

  if (url.isEmpty) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.grey.shade200,
      child: Icon(Icons.person, size: radius, color: Colors.grey),
    );
  }

  final bustUrl =
      '$url${url.contains('?') ? '&' : '?'}t=${DateTime.now().millisecondsSinceEpoch}';

  return ClipOval(
    child: SizedBox(
      width: size,
      height: size,
      child: HtmlElementView.fromTagName(
        tagName: 'img',
        onElementCreated: (Object element) {
          final img = element as web.HTMLImageElement;
          img.src = bustUrl;
          img.style.width = '100%';
          img.style.height = '100%';
          img.style.objectFit = 'cover';
          img.draggable = false;
        },
      ),
    ),
  );
}