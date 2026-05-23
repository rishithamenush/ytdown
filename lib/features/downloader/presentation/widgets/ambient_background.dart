import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Soft animated-feeling green glow blobs that sit behind the home page.
/// Pure decoration — no inputs, no state.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (!isDark) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F8FC), Color(0xFFF1F1F7)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      );
    }
    return const Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.subtleGradient),
          ),
        ),
        Positioned(
          top: -120,
          left: -80,
          child: _GlowBlob(
            color: AppTheme.brandPrimary,
            size: 340,
            opacity: 0.35,
          ),
        ),
        Positioned(
          top: 40,
          right: -120,
          child: _GlowBlob(
            color: AppTheme.brandAccent,
            size: 300,
            opacity: 0.28,
          ),
        ),
        Positioned(
          top: 240,
          left: -60,
          child: _GlowBlob(
            color: AppTheme.brandSecondary,
            size: 240,
            opacity: 0.18,
          ),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
