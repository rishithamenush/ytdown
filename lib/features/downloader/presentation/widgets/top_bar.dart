import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.activeCount,
    this.title = 'Vidoory',
    this.subtitle = 'Fast video & audio saver',
    this.onSettingsTap,
  });

  final int activeCount;
  final String title;
  final String subtitle;
  final VoidCallback? onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hPad = Responsive.horizontalPadding(context);
    final logoSize = Responsive.scale(context, 56);
    final iconSize = Responsive.scale(context, 32);
    final titleSize = Responsive.scale(context, 26);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 8),
      child: Row(
        children: [
          Container(
            width: logoSize,
            height: logoSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(logoSize * 0.28),
              gradient: AppTheme.downloadGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.downloadGreen.withValues(alpha: 0.5),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              Icons.download_rounded,
              color: Colors.white,
              size: iconSize,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    fontSize: titleSize,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (activeCount > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: AppTheme.brandGradient,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$activeCount active',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            if (onSettingsTap != null) const SizedBox(width: 8),
          ],
          if (onSettingsTap != null) _SettingsGear(onTap: onSettingsTap!),
        ],
      ),
    );
  }
}

class _SettingsGear extends StatelessWidget {
  const _SettingsGear({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Icon(
            Icons.settings_outlined,
            size: 22,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
