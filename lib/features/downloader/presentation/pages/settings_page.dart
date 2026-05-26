import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';
import '../widgets/ambient_background.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Settings',
          style: theme.textTheme.titleLarge,
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
              physics: const BouncingScrollPhysics(),
              children: [
                _SectionTitle(text: 'About'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: Icons.info_outline_rounded,
                      title: 'Version',
                      trailing: Text(
                        '1.0.0',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const _Divider(),
                    _SettingsRow(
                      icon: Icons.folder_outlined,
                      title: 'Save location',
                      subtitle: 'Movies/Vidoory (video) · Download/Vidoory (audio)',
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _SectionTitle(text: 'Resources'),
                const SizedBox(height: 10),
                _SettingsCard(
                  children: [
                    _SettingsRow(
                      icon: Icons.shield_outlined,
                      title: 'Privacy',
                      subtitle: 'Vidoory does not collect personal data.',
                    ),
                    const _Divider(),
                    _SettingsRow(
                      icon: Icons.help_outline_rounded,
                      title: 'How to use',
                      subtitle:
                          'Paste a YouTube or TikTok link on Home, choose a quality, and tap Download.',
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                Center(
                  child: Text(
                    'Made with Flutter',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: children),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.brandPrimary.withValues(alpha: 0.18),
                  AppTheme.brandPrimary.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(
                color: AppTheme.brandPrimary.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(icon, color: AppTheme.brandPrimary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Divider(
        height: 1,
        color: Theme.of(context).dividerTheme.color,
      ),
    );
  }
}
