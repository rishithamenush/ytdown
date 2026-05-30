import 'dart:math' as math;

import 'package:flutter/widgets.dart';

class Responsive {
  Responsive._();

  static const double compactPhone = 360;
  static const double tablet = 600;
  static const double largeTablet = 900;
  static const double maxContentWidth = 640;

  static double width(BuildContext c) => MediaQuery.sizeOf(c).width;

  static bool isCompact(BuildContext c) => width(c) < compactPhone;
  static bool isPhone(BuildContext c) => width(c) < tablet;
  static bool isTablet(BuildContext c) =>
      width(c) >= tablet && width(c) < largeTablet;
  static bool isLargeTablet(BuildContext c) => width(c) >= largeTablet;

  static double horizontalPadding(BuildContext c) {
    final w = width(c);
    if (w >= maxContentWidth + 40) {
      return (w - maxContentWidth) / 2;
    }
    if (w < compactPhone) return 14;
    if (w < tablet) return 20;
    return 24;
  }

  static double scale(
    BuildContext c,
    double base, {
    double compact = 0.92,
    double tablet = 1.12,
    double largeTablet = 1.18,
  }) {
    final w = width(c);
    double factor;
    if (w < compactPhone) {
      factor = compact;
    } else if (w < Responsive.tablet) {
      factor = 1.0;
    } else if (w < Responsive.largeTablet) {
      factor = tablet;
    } else {
      factor = largeTablet;
    }
    return base * factor;
  }

  static double shortestSide(BuildContext c) {
    final size = MediaQuery.sizeOf(c);
    return math.min(size.width, size.height);
  }

  /// Glass bottom bar (68) + outer padding (12) + system inset.
  static const double bottomNavBarHeight = 68;
  static const double bottomNavOuterPadding = 12;

  static double bottomNavInset(BuildContext c) {
    return bottomNavBarHeight +
        bottomNavOuterPadding +
        MediaQuery.paddingOf(c).bottom;
  }

  /// List/scroll padding so content clears the floating bottom nav.
  static double scrollBottomPadding(BuildContext c, {double extra = 16}) {
    return bottomNavInset(c) + extra;
  }
}
