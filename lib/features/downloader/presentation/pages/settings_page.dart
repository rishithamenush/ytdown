import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart' show Share;
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/app/app_version_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';
import '../providers/home_notifier.dart';
import '../widgets/ambient_background.dart';
import '../widgets/top_bar.dart';

const _appId = 'com.vidoory.app';
const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=$_appId';
const _privacyPolicyUrl = 'https://vidoory.app/privacy';
const _supportEmail = 'support@vidoory.app';

Future<void> _openUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not open link')),
    );
  }
}

Future<void> _rateApp(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final market = Uri.parse('market://details?id=$_appId');
  if (!await launchUrl(market)) {
    final web = Uri.parse(_playStoreUrl);
    if (!await launchUrl(web, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open Play Store')),
      );
    }
  }
}

Future<void> _shareApp() async {
  await Share.share(
    'Check out Vidoory — the fastest video & audio saver!\n$_playStoreUrl',
    subject: 'Vidoory - Fast Video Saver',
  );
}

Future<void> _contactSupport(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri(
    scheme: 'mailto',
    path: _supportEmail,
    queryParameters: {'subject': 'Vidoory Support'},
  );
  if (!await launchUrl(uri)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('No email app found')),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hPad = Responsive.horizontalPadding(context);
    final versionAsync = ref.watch(packageInfoProvider);
    final activeCount = ref.watch(
      homeNotifierProvider.select((s) => s.activeTaskCount),
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
            child: Column(
              children: [
                TopBar(
                  activeCount: activeCount,
                  title: 'Settings',
                  subtitle: 'Preferences & info',
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 40),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _SectionTitle(text: 'About'),
                      const SizedBox(height: 10),
                      _SettingsCard(
                        children: [
                          _SettingsRow(
                            icon: Icons.info_outline_rounded,
                            title: 'Version',
                            trailing: versionAsync.when(
                              data: (info) => Text(
                                formatAppVersion(info),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              loading: () => SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              error: (_, __) => Text(
                                '—',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          const _Divider(),
                          _SettingsRow(
                            icon: Icons.folder_outlined,
                            title: 'Save location',
                            subtitle:
                                'Movies/Vidoory (video)  ·  Download/Vidoory (audio)',
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SectionTitle(text: 'App'),
                      const SizedBox(height: 10),
                      _SettingsCard(
                        children: [
                          if (Platform.isAndroid) ...[
                            _SettingsRow(
                              icon: Icons.star_rate_rounded,
                              title: 'Rate Vidoory',
                              subtitle: 'Love the app? Leave us a review!',
                              onTap: () => _rateApp(context),
                              showArrow: true,
                            ),
                            const _Divider(),
                          ],
                          _SettingsRow(
                            icon: Icons.share_outlined,
                            title: 'Share Vidoory',
                            subtitle: 'Tell your friends about the app',
                            onTap: _shareApp,
                            showArrow: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SectionTitle(text: 'Support'),
                      const SizedBox(height: 10),
                      _SettingsCard(
                        children: [
                          _SettingsRow(
                            icon: Icons.help_outline_rounded,
                            title: 'How to use',
                            subtitle:
                                'Paste a YouTube, TikTok, or Facebook link on '
                                'Home, choose a quality, and tap Download.',
                          ),
                          const _Divider(),
                          _SettingsRow(
                            icon: Icons.mail_outline_rounded,
                            title: 'Contact Support',
                            subtitle: _supportEmail,
                            onTap: () => _contactSupport(context),
                            showArrow: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SectionTitle(text: 'Legal'),
                      const SizedBox(height: 10),
                      _SettingsCard(
                        children: [
                          _SettingsRow(
                            icon: Icons.shield_outlined,
                            title: 'Privacy Policy',
                            subtitle: 'Vidoory does not collect personal data.',
                            onTap: () =>
                                _openUrl(context, _privacyPolicyUrl),
                            showArrow: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 36),
                      const _LegalFooter(),
                    ],
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

// ── Section title ─────────────────────────────────────────────────────────────

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

// ── Settings card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

// ── Settings row ──────────────────────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showArrow = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content = Padding(
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
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
          if (showArrow && onTap != null) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: content);
    }
    return content;
  }
}

// ── Divider ───────────────────────────────────────────────────────────────────

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

// ── Legal footer ──────────────────────────────────────────────────────────────

class _LegalFooter extends StatelessWidget {
  const _LegalFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        'Vidoory is intended for downloading content you own or have the right '
        'to download. Please respect copyright laws and the terms of service of '
        'each platform.\n\n'
        '© ${DateTime.now().year} Vidoory. All rights reserved.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          fontSize: 11.5,
          height: 1.55,
        ),
      ),
    );
  }
}
