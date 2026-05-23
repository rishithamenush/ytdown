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
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.brandPrimary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(9),
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
