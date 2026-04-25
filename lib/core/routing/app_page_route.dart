import 'package:flutter/material.dart';

/// Smooth slide-from-right transition for all screen pushes.
/// Drop-in replacement for MaterialPageRoute.
///
/// Usage:
///   Navigator.push(context, AppPageRoute(builder: (_) => MyScreen()));
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({required WidgetBuilder builder, RouteSettings? settings})
      : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder:
              (context, animation, secondaryAnimation, child) {
            // Incoming page slides in from right
            final inSlide = Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));

            // Outgoing page fades slightly (depth illusion)
            final outFade = Tween<double>(begin: 1.0, end: 0.95).animate(
              CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeOut,
              ),
            );

            return FadeTransition(
              opacity: outFade,
              child: SlideTransition(position: inSlide, child: child),
            );
          },
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 260),
        );
}

/// Fade + scale-up transition — great for modals/overlays.
class AppFadeRoute<T> extends PageRouteBuilder<T> {
  AppFadeRoute({required WidgetBuilder builder, RouteSettings? settings})
      : super(
          settings: settings,
          pageBuilder: (context, animation, _) => builder(context),
          transitionsBuilder: (context, animation, _, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            );
          },
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 220),
        );
}
