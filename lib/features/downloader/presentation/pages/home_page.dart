import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';
import '../../../../core/utils/video_link_parser.dart';
import '../../data/models/direct_link_download_stream.dart';
import '../../domain/entities/download_stream.dart';
import '../../domain/entities/download_task.dart';
import '../providers/home_notifier.dart';
import '../providers/providers.dart';
import '../widgets/direct_link_browser_sheet.dart';
import '../widgets/ambient_background.dart';
import '../widgets/error_banner.dart';
import '../widgets/gradient_button.dart';
import '../widgets/quality_tile.dart';
import '../widgets/search_field.dart';
import '../widgets/section_header.dart';
import '../widgets/top_bar.dart';
import '../widgets/video_preview_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    FocusScope.of(context).unfocus();
    final notifier = ref.read(homeNotifierProvider.notifier);
    await notifier.fetchVideo(_urlController.text);
    if (!mounted) return;

    final state = ref.read(homeNotifierProvider);
    if (state.error != null) return;

    for (final stream in state.streams) {
      if (stream is DirectLinkDownloadStream &&
          stream.requiresBrowserSession) {
        final verified = await _ensureBrowserSession(stream.directUrl);
        if (!mounted || !verified) return;
        await notifier.fetchVideo(_urlController.text);
        return;
      }
    }
  }

  Future<bool> _ensureBrowserSession(String fileUrl) async {
    final host = Uri.tryParse(fileUrl)?.host ?? '';
    if (host.isEmpty) return false;

    final store = ref.read(directLinkCookieStoreProvider);
    if (store.hasSession(host)) return true;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DirectLinkBrowserSheet(
        fileUrl: fileUrl,
        cookieStore: store,
      ),
    );
    return ok == true;
  }

  Future<void> _startDownload(DownloadStream stream) async {
    if (stream is DirectLinkDownloadStream) {
      final host = Uri.tryParse(stream.directUrl)?.host ?? '';
      final store = ref.read(directLinkCookieStoreProvider);
      if (stream.requiresBrowserSession && !store.hasSession(host)) {
        final verified = await _ensureBrowserSession(stream.directUrl);
        if (!mounted || !verified) return;
        await ref.read(homeNotifierProvider.notifier).fetchVideo(
              _urlController.text,
            );
        if (!mounted) return;
        final updated = ref.read(homeNotifierProvider).streams;
        final match = updated.whereType<DirectLinkDownloadStream>().firstOrNull;
        if (match != null) {
          stream = match;
        }
      }
    }
    if (!mounted) return;
    await ref.read(homeNotifierProvider.notifier).startDownload(stream);
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _urlController.text = text;
    _urlController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    if (VideoLinkParser.detect(text) != null) {
      await _fetch();
    }
  }

  void _cancelFetch() {
    ref.read(homeNotifierProvider.notifier).cancelFetch();
  }

  void _clearSearch() {
    _urlController.clear();
    ref.read(homeNotifierProvider.notifier).clearSearch();
  }

  Future<void> _openTaskFile(DownloadTask task) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(homeNotifierProvider.notifier)
        .openTaskFile(task);
    if (!mounted || error == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(error),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(homeNotifierProvider);
    final notifier = ref.read(homeNotifierProvider.notifier);
    final hPad = Responsive.horizontalPadding(context);
    final pastedUrl = _urlController.text.trim();
    final isDirectFile =
        VideoLinkParser.detect(pastedUrl) == VideoSourcePlatform.directLink;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
            child: Column(
              children: [
                TopBar(activeCount: state.activeTaskCount),
                Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      SearchField(
                        controller: _urlController,
                        loading: state.loading,
                        onSubmit: _fetch,
                        onPaste: _paste,
                        onClear: _clearSearch,
                      ),
                      const SizedBox(height: 14),
                      GradientButton(
                        onPressed: state.loading ? null : _fetch,
                        loading: state.loading,
                        label: state.loading
                            ? (isDirectFile || state.video?.isDirectLink == true
                                ? 'Checking file…'
                                : 'Fetching video…')
                            : (isDirectFile || state.video?.isDirectLink == true
                                ? 'Get file'
                                : 'Get video'),
                        icon: Icons.search_rounded,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: state.loading
                            ? Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: SizedBox(
                                  height: Responsive.scale(context, 38),
                                  child: TextButton(
                                    onPressed: _cancelFetch,
                                    style: TextButton.styleFrom(
                                      foregroundColor: theme.colorScheme.onSurfaceVariant,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 24),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: theme.colorScheme.outline
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 16),
                        ErrorBanner(message: state.error!),
                      ],
                      if (state.video == null &&
                          !state.loading &&
                          state.error == null) ...[
                        const SizedBox(height: 28),
                        const _SupportedPlatformsHint(),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
                        sliver: SliverList.list(
                          children: [
                            if (state.video != null) ...[
                              VideoPreviewCard(video: state.video!),
                              const SizedBox(height: 24),
                              SectionHeader(
                                icon: Icons.high_quality_rounded,
                                title: state.video!.isDirectLink
                                    ? 'Ready to download'
                                    : 'Choose quality',
                                subtitle: state.video!.isTikTok
                                    ? 'TikTok downloads save without watermark when available.'
                                    : state.video!.isFacebook
                                        ? 'Facebook downloads come in HD or SD. Public videos only.'
                                        : state.video!.isDirectLink
                                            ? (state.streams.any(
                                                (s) =>
                                                    s is DirectLinkDownloadStream &&
                                                    s.requiresBrowserSession,
                                              )
                                                ? 'This host uses browser protection — verify once, then download.'
                                                : 'Downloaded over multiple connections for max speed.')
                                            : 'Tap multiple to download in parallel. HD options merge video + audio.',
                              ),
                              const SizedBox(height: 12),
                              ...state.streams.map((stream) {
                                final task = notifier.taskForStream(stream);
                                final downloading = task?.isActive ?? false;
                                final completed =
                                    task?.status == DownloadTaskStatus.completed
                                        ? task
                                        : null;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: QualityTile(
                                    stream: stream,
                                    activeTask: downloading ? task : null,
                                    completedTask: completed,
                                    onTap: downloading
                                        ? null
                                        : () => _startDownload(stream),
                                    onOpenCompleted: () {
                                      if (completed != null) {
                                        _openTaskFile(completed);
                                      }
                                    },
                                  ),
                                );
                              }),
                              const SizedBox(height: 12),
                              Text(
                                'Files save to Movies/Vidoory (video) or '
                                'Download/Vidoory (audio). Track them in the '
                                'Library tab.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ),
                      ),
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

// ── Supported platforms hint ──────────────────────────────────────────────────

class _SupportedPlatformsHint extends StatelessWidget {
  const _SupportedPlatformsHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          'Supported platforms',
          style: theme.textTheme.bodySmall?.copyWith(
            letterSpacing: 0.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: const [
            _PlatformChip(
              label: 'YouTube',
              icon: Icons.smart_display_rounded,
              color: Color(0xFFFF0033),
            ),
            _PlatformChip(
              label: 'TikTok',
              icon: Icons.music_note_rounded,
              color: Color(0xFF69C9D0),
            ),
            _PlatformChip(
              label: 'Facebook',
              icon: Icons.people_alt_rounded,
              color: Color(0xFF1877F2),
            ),
            _PlatformChip(
              label: 'Direct Links',
              icon: Icons.link_rounded,
              color: AppTheme.brandPrimary,
            ),
          ],
        ),
      ],
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}
