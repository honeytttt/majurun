// ignore: avoid_web_libraries_in_flutter
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
