// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
// Note: dart:html is deprecated, but package:web migration is complex for iframe srcdoc
// TODO: Migrate to package:web when better documentation is available
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/widgets.dart';

int _counter = 0;

Widget createWebWorkoutView(String htmlContent, String workoutType) {
  final viewType = 'workout-html-view-${_counter++}';

  // Register the view factory
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#040404'
      ..srcdoc = htmlContent;

    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
