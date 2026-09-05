import 'package:flutter/material.dart';

/// Lightweight Neubrutalist slide/fade page transition per DESIGN.md §7:
/// "Screen transitions: quick slide/fade 150–200 ms. Feed first-load:
/// short stagger. No parallax, no blur transitions, no infinite marquees in v1.
/// Respect reduced-motion settings."
///
/// Designed to eliminate lag, stutter, and frame drops on Android emulators
/// and low-end devices by caching textures in a [RepaintBoundary] and avoiding
/// expensive multi-layer saveLayer alpha compositing across both screens.
class BrutalPageTransitionsBuilder extends PageTransitionsBuilder {
  const BrutalPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildBrutalPageTransitions(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

/// Builds the snappy Neubrutalist slide and fade page transition.
Widget buildBrutalPageTransitions(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  // If animations are completed and route is idle, avoid wrapping in transforms.
  if (animation.status == AnimationStatus.completed &&
      secondaryAnimation.status == AnimationStatus.dismissed) {
    return child;
  }

  // Respect system accessibility setting for reduced motion.
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
    return child;
  }

  // Fast, snappy deceleration curve (180ms forward, 150ms reverse)
  final curvedAnimation = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  // Subtle 6% horizontal slide from the right
  final slideIn = Tween<Offset>(
    begin: const Offset(0.06, 0.0),
    end: Offset.zero,
  ).animate(curvedAnimation);

  // Smooth opacity fade
  final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation);

  // Subtle exit dim for route underneath without expensive transforms
  final secondaryCurved = CurvedAnimation(
    parent: secondaryAnimation,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  final secondaryFade = Tween<double>(
    begin: 1.0,
    end: 0.90,
  ).animate(secondaryCurved);

  return RepaintBoundary(
    child: SlideTransition(
      position: slideIn,
      child: FadeTransition(
        opacity: fadeIn,
        child: FadeTransition(opacity: secondaryFade, child: child),
      ),
    ),
  );
}

/// High-performance Neubrutalist [PageRouteBuilder] configured for 180ms
/// enter and 150ms exit transitions.
class BrutalPageRoute<T> extends PageRouteBuilder<T> {
  BrutalPageRoute({
    required WidgetBuilder builder,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionDuration: const Duration(milliseconds: 180),
         reverseTransitionDuration: const Duration(milliseconds: 150),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           return buildBrutalPageTransitions(
             context,
             animation,
             secondaryAnimation,
             child,
           );
         },
       );
}
