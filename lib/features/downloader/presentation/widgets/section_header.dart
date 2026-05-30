import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingAction,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailingAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.brandPrimary.withValues(alpha: 0.20),
                    AppTheme.brandPrimary.withValues(alpha: 0.07),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(icon, color: AppTheme.brandPrimary, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            if (trailingAction != null) trailingAction!,
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
