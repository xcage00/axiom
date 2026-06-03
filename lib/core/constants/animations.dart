import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppAnimations {
  // Durations
  static const Duration fastest = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration normal = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 600);
  
  // Curves
  static const Curve spring = Curves.elasticOut;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve bounce = Curves.bounceOut;
  
  // Page transitions
  static const PageTransitionsTheme pageTransitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
    },
  );
}

// Haptic feedback - works on mobile only
class Haptic {
  static void light() {
    try {
      HapticFeedback.lightImpact();
    } catch (e) {
      // Web doesn't support haptics
    }
  }
  
  static void medium() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Web doesn't support haptics
    }
  }
  
  static void heavy() {
    try {
      HapticFeedback.heavyImpact();
    } catch (e) {
      // Web doesn't support haptics
    }
  }
  
  static void selection() {
    try {
      HapticFeedback.selectionClick();
    } catch (e) {
      // Web doesn't support haptics
    }
  }
}