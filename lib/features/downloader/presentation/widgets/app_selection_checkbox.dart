import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Rounded selection control aligned with the app's green card aesthetic.
class AppSelectionCheckbox extends StatelessWidget {
  const AppSelectionCheckbox({
    super.key,
    required this.selected,
    required this.onChanged,
    this.size = 26,
  });

  final bool selected;
  final ValueChanged<bool> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Semantics(
      checked: selected,
      button: true,
      label: selected ? 'Selected' : 'Not selected',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(size * 0.32),
          ),
          onTap: () => onChanged(!selected),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.32),
              gradient: selected ? AppTheme.brandGradient : null,
              color: selected
                  ? null
                  : (isDark
                      ? const Color(0xFF1A1A22)
                      : const Color(0xFFF0F0F5)),
              border: Border.all(
                color: selected ? AppTheme.brandPrimary : borderColor,
                width: selected ? 1.2 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppTheme.brandPrimary.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: size * 0.62,
                    color: Colors.white,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
