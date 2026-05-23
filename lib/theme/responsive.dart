import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Responsive breakpoints + helpers. Content is centered on tablets/desktops
/// with a max readable width, and key sizes scale modestly on small phones
/// (< 360 dp) and tablets (>= 600 dp).
class Responsive {
  Responsive._();

  /// Below this width, treat as a compact phone (extra-tight paddings).
  static const double compactPhone = 360;

  /// At or above this width, treat as a tablet (wider paddings, larger type).
  static const double tablet = 600;

  /// At or above this width, treat as a large tablet / desktop.
  static const double largeTablet = 900;

  /// Max readable width for the main content column. On wider screens the
  /// content is centered with extra side margin so lines don't run too long.
  static const double maxContentWidth = 640;

  static double width(BuildContext c) => MediaQuery.sizeOf(c).width;

  static bool isCompact(BuildContext c) => width(c) < compactPhone;
  static bool isPhone(BuildContext c) => width(c) < tablet;
  static bool isTablet(BuildContext c) =>
      width(c) >= tablet && width(c) < largeTablet;
  static bool isLargeTablet(BuildContext c) => width(c) >= largeTablet;

  /// Symmetric horizontal padding for the main content. Returns a wide margin
  /// on tablets so the content column stays close to [maxContentWidth] without
  /// stretching edge-to-edge on landscape iPads / Chromebooks.
  static double horizontalPadding(BuildContext c) {
    final w = width(c);
    if (w >= maxContentWidth + 40) {
      return (w - maxContentWidth) / 2;
    }
    if (w < compactPhone) return 14;
    if (w < tablet) return 20;
    return 24;
  }

  /// Multiplies a base size by a screen-size-dependent factor. Use for fonts,
  /// icon sizes, and accent containers (logo tile, CTA height) so they grow
  /// on tablets without ballooning on giant displays.
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

  /// Returns the smaller of the screen's logical sides. Useful when scaling
  /// elements that need to fit comfortably regardless of orientation.
  static double shortestSide(BuildContext c) {
    final size = MediaQuery.sizeOf(c);
    return math.min(size.width, size.height);
  }
}
