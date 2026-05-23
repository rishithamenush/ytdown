import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';

class HeroSection extends StatelessWidget {
  const HeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heroSize = Responsive.scale(context, 32);
    final subSize = Responsive.scale(context, 14);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ShaderMask(
          shaderCallback: (rect) =>
              AppTheme.brandGradient.createShader(rect),
          child: Text(
            'Save any video.\nKeep it offline.',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1.05,
              fontSize: heroSize,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Paste a link to grab the highest quality video or audio, in seconds.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: subSize,
          ),
        ),
      ],
    );
  }
}
