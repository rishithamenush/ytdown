import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/download_task.dart';
import '../services/background_download_service.dart';
import '../services/youtube_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _urlController = TextEditingController();
  final _service = YoutubeService();
  final _downloadTasks = <DownloadTask>[];
  int _taskIdCounter = 0;
  DateTime _lastNotificationUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  Video? _video;
  List<DownloadableStream> _streams = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _urlController.dispose();
    _service.dispose();
    super.dispose();
  }

  static String _formatDuration(Duration? d) {
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  bool _isStreamDownloading(int index) {
    final videoId = _video?.id.value;
    if (videoId == null) return false;
    return _downloadTasks.any(
      (t) =>
          t.videoId == videoId &&
          t.streamId == _streams[index].id &&
          t.isActive,
    );
  }

  Future<void> _fetchVideo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Paste a video link to get started');
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
      _video = null;
      _streams = [];
    });

    try {
      final video = await _service.getVideo(url);
      final streams = await _service.getDownloadOptions(url);
      if (streams.isEmpty) {
        throw Exception('No downloadable streams found for this video');
      }
      setState(() {
        _video = video;
        _streams = streams;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _urlController.text = text;
    _urlController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  void _cancelTask(DownloadTask task) {
    task.cancelToken.cancel();
  }

  void _removeTask(String id) {
    setState(() => _downloadTasks.removeWhere((t) => t.id == id));
  }

  DownloadTask? _taskForStream(int index) {
    final videoId = _video?.id.value;
    if (videoId == null) return null;
    final streamId = _streams[index].id;
    for (final t in _downloadTasks) {
      if (t.videoId == videoId && t.streamId == streamId) {
        return t;
      }
    }
    return null;
  }

  Future<void> _download(int index) async {
    final option = _streams[index];
    final video = _video;
    if (video == null || _isStreamDownloading(index)) return;

    await BackgroundDownloadService.requestPermissions();

    final task = DownloadTask(
      id: '${++_taskIdCounter}',
      videoId: video.id.value,
      videoTitle: video.title,
      qualityLabel: option.label,
      streamId: option.id,
      isVideo: option.isVideo,
      cancelToken: DownloadCancelToken(),
    );

    setState(() {
      _downloadTasks.insert(0, task);
      _error = null;
    });
    _syncBackgroundService(force: true);

    unawaited(_runDownload(task, option));
  }

  Future<void> _runDownload(DownloadTask task, DownloadableStream option) async {
    try {
      final path = await _service.downloadOption(
        option: option,
        fileName: task.videoTitle,
        fileSuffix: task.id,
        cancelToken: task.cancelToken,
        onProgress: (p) {
          if (!mounted) return;
          setState(() => task.progress = p);
          _syncBackgroundService();
        },
      );

      if (!mounted) return;
      setState(() {
        task.status = DownloadTaskStatus.completed;
        task.savedPath = path;
      });
    } on DownloadCancelledException {
      if (!mounted) return;
      setState(() => task.status = DownloadTaskStatus.cancelled);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        task.status = DownloadTaskStatus.failed;
        task.errorMessage = e.toString();
      });
    } finally {
      _syncBackgroundService(force: true);
    }
  }

  void _syncBackgroundService({bool force = false}) {
    if (!BackgroundDownloadService.isSupported) return;
    final active = _downloadTasks.where((t) => t.isActive).toList();
    if (active.isEmpty) {
      _lastNotificationUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      unawaited(BackgroundDownloadService.stop());
      return;
    }

    final now = DateTime.now();
    if (!force &&
        now.difference(_lastNotificationUpdate).inMilliseconds < 750) {
      return;
    }
    _lastNotificationUpdate = now;

    final title = active.length == 1
        ? 'Downloading 1 file'
        : 'Downloading ${active.length} files';

    final hasTotals = active.every((t) => t.progress.hasTotal);
    String text;
    if (active.length == 1) {
      final t = active.first;
      final p = t.progress;
      text = p.hasTotal
          ? '${p.percent}% · ${t.videoTitle}'
          : 'Starting · ${t.videoTitle}';
    } else if (hasTotals) {
      final avg = active.fold<double>(0, (sum, t) => sum + t.progress.fraction) /
          active.length;
      text = '${(avg * 100).round()}% overall';
    } else {
      text = 'In progress…';
    }

    unawaited(BackgroundDownloadService.start(title: title, text: text));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCount = _downloadTasks.where((t) => t.isActive).length;
    final hasFinished = _downloadTasks.any((t) => !t.isActive);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackground()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _TopBar(activeCount: activeCount),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  sliver: SliverList.list(
                    children: [
                      const _Hero(),
                      const SizedBox(height: 20),
                      _SearchField(
                        controller: _urlController,
                        loading: _loading,
                        onSubmit: _fetchVideo,
                        onPaste: _pasteFromClipboard,
                      ),
                      const SizedBox(height: 14),
                      _GradientButton(
                        onPressed: _loading ? null : _fetchVideo,
                        loading: _loading,
                        label: _loading ? 'Fetching video…' : 'Get video',
                        icon: Icons.search_rounded,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorBanner(message: _error!),
                      ],
                      if (_downloadTasks.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _SectionHeader(
                          icon: Icons.downloading_rounded,
                          title: 'Downloads',
                          trailingAction: hasFinished
                              ? TextButton(
                                  onPressed: () => setState(
                                    () => _downloadTasks
                                        .removeWhere((t) => !t.isActive),
                                  ),
                                  child: const Text('Clear finished'),
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        ..._downloadTasks.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _DownloadTaskTile(
                              task: t,
                              onCancel: () => _cancelTask(t),
                              onDismiss: () => _removeTask(t.id),
                            ),
                          ),
                        ),
                      ],
                      if (_video != null) ...[
                        const SizedBox(height: 28),
                        _VideoPreviewCard(
                          video: _video!,
                          formattedDuration: _formatDuration(_video!.duration),
                        ),
                        const SizedBox(height: 24),
                        _SectionHeader(
                          icon: Icons.high_quality_rounded,
                          title: 'Choose quality',
                          subtitle:
                              'Tap multiple to download in parallel. HD options merge video + audio.',
                        ),
                        const SizedBox(height: 12),
                        ...List.generate(_streams.length, (i) {
                          final option = _streams[i];
                          final task = _taskForStream(i);
                          final downloading = task?.isActive ?? false;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _QualityTile(
                              option: option,
                              activeTask: downloading ? task : null,
                              completed: task?.status ==
                                      DownloadTaskStatus.completed
                                  ? task
                                  : null,
                              onTap: downloading ? null : () => _download(i),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Text(
                          'Files save to Movies/Vidoory (video) or Download/Vidoory (audio).',
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Background
// ─────────────────────────────────────────────────────────────────────────────

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

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
    return Stack(
      children: [
        const Positioned.fill(
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

// ─────────────────────────────────────────────────────────────────────────────
//  Top bar + hero
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: AppTheme.downloadGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.downloadGreen.withValues(alpha: 0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.download_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vidoory',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'Fast video & audio saver',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const Spacer(),
          if (activeCount > 0)
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
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Paste a link to grab the highest quality video or audio, in seconds.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Search field + primary CTA
// ─────────────────────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.loading,
    required this.onSubmit,
    required this.onPaste,
  });

  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: !loading,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmit(),
      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Paste video link here…',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.brandPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.link_rounded,
              color: AppTheme.brandPrimary,
              size: 20,
            ),
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 60),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Clear',
                  onPressed: () => controller.clear(),
                ),
              IconButton(
                icon: const Icon(Icons.content_paste_rounded, size: 20),
                tooltip: 'Paste',
                onPressed: onPaste,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: SizedBox(
        height: 56,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: AppTheme.brandGradient,
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppTheme.brandPrimary.withValues(alpha: 0.4),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onPressed,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    else
                      Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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

// ─────────────────────────────────────────────────────────────────────────────
//  Video preview
// ─────────────────────────────────────────────────────────────────────────────

class _VideoPreviewCard extends StatelessWidget {
  const _VideoPreviewCard({
    required this.video,
    required this.formattedDuration,
  });

  final Video video;
  final String formattedDuration;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = video.thumbnails.highResUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      thumb,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, p) {
                        if (p == null) return child;
                        return ColoredBox(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Color(0x99000000),
                          ],
                          stops: [0, 0.55, 1],
                        ),
                      ),
                    ),
                    if (formattedDuration.isNotEmpty)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            formattedDuration,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              video.title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    video.author,
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Quality tile
// ─────────────────────────────────────────────────────────────────────────────

class _QualityTile extends StatelessWidget {
  const _QualityTile({
    required this.option,
    required this.activeTask,
    required this.completed,
    required this.onTap,
  });

  final DownloadableStream option;
  final DownloadTask? activeTask;
  final DownloadTask? completed;
  final VoidCallback? onTap;

  bool get _isAudio => !option.isVideo;

  String get _badge {
    if (_isAudio) return 'AUDIO';
    final h = option.videoHeight;
    if (h == null) return 'SD';
    if (h >= 2160) return '4K';
    if (h >= 1440) return '2K';
    if (h >= 1080) return 'FHD';
    if (h >= 720) return 'HD';
    return 'SD';
  }

  IconData get _icon =>
      _isAudio ? Icons.graphic_eq_rounded : Icons.movie_filter_rounded;

  Color _badgeColor() {
    if (_isAudio) return AppTheme.brandAccent;
    final h = option.videoHeight ?? 0;
    if (h >= 2160) return const Color(0xFFFFB020);
    if (h >= 1080) return AppTheme.brandPrimary;
    return AppTheme.brandSecondary;
  }

  String _title() {
    if (_isAudio) return 'Audio only';
    final h = option.videoHeight;
    if (h == null) return option.label;
    return '${h}p';
  }

  String _subtitle() {
    final size = _formatBytes(option.estimatedSizeBytes);
    final ext = option.extension;
    if (option.isMerged) {
      return 'Video + audio merge · .$ext · ≈$size';
    }
    if (_isAudio) {
      return 'Best audio · .$ext · ≈$size';
    }
    return 'Quick (no merge) · .$ext · ≈$size';
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloading = activeTask != null;
    final done = completed != null;
    final progress = activeTask?.progress;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _badgeColor().withValues(alpha: 0.22),
                          _badgeColor().withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: _badgeColor().withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(_icon, color: _badgeColor(), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_title(), style: theme.textTheme.titleMedium),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _badgeColor().withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _badge,
                                style: GoogleFonts.plusJakartaSans(
                                  color: _badgeColor(),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_subtitle(), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _trailing(theme, downloading, done, progress),
                ],
              ),
              if (downloading && progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress.hasTotal ? progress.fraction : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  progress.hasTotal
                      ? '${progress.percent}% · ${_formatBytes(progress.downloadedBytes)} / ${_formatBytes(progress.totalBytes)}'
                      : '${_formatBytes(progress.downloadedBytes)} downloaded',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(
    ThemeData theme,
    bool downloading,
    bool done,
    DownloadProgress? progress,
  ) {
    if (downloading) {
      return SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              value: progress?.hasTotal == true ? progress!.fraction : null,
            ),
            if (progress?.hasTotal == true)
              Text(
                '${progress!.percent}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      );
    }
    if (done) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.brandSecondary.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: AppTheme.brandSecondary,
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: AppTheme.downloadGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.downloadGreen.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.download_rounded, color: Colors.white),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Active download tile
// ─────────────────────────────────────────────────────────────────────────────

class _DownloadTaskTile extends StatelessWidget {
  const _DownloadTaskTile({
    required this.task,
    required this.onCancel,
    required this.onDismiss,
  });

  final DownloadTask task;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Color _accent(ThemeData theme) {
    switch (task.status) {
      case DownloadTaskStatus.completed:
        return AppTheme.brandSecondary;
      case DownloadTaskStatus.failed:
        return theme.colorScheme.error;
      case DownloadTaskStatus.cancelled:
        return theme.colorScheme.onSurfaceVariant;
      case DownloadTaskStatus.downloading:
        return AppTheme.brandPrimary;
    }
  }

  IconData _icon() {
    switch (task.status) {
      case DownloadTaskStatus.completed:
        return Icons.check_circle_rounded;
      case DownloadTaskStatus.failed:
        return Icons.error_outline_rounded;
      case DownloadTaskStatus.cancelled:
        return Icons.cancel_rounded;
      case DownloadTaskStatus.downloading:
        return Icons.download_rounded;
    }
  }

  String _statusLabel() {
    switch (task.status) {
      case DownloadTaskStatus.completed:
        return 'Saved · ${task.isVideo ? 'Movies/Vidoory' : 'Download/Vidoory'}';
      case DownloadTaskStatus.failed:
        return task.errorMessage ?? 'Download failed';
      case DownloadTaskStatus.cancelled:
        return 'Cancelled';
      case DownloadTaskStatus.downloading:
        return task.progress.hasTotal
            ? '${_formatBytes(task.progress.downloadedBytes)} / ${_formatBytes(task.progress.totalBytes)}'
            : '${_formatBytes(task.progress.downloadedBytes)} downloaded';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = task.progress;
    final accent = _accent(theme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _leading(accent, progress),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.videoTitle,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.qualityLabel,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    task.isActive
                        ? Icons.close_rounded
                        : Icons.delete_outline_rounded,
                    size: 20,
                  ),
                  tooltip: task.isActive ? 'Cancel' : 'Dismiss',
                  onPressed: task.isActive ? onCancel : onDismiss,
                ),
              ],
            ),
            if (task.isActive) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progress.hasTotal ? progress.fraction : null,
                ),
              ),
              const SizedBox(height: 6),
            ] else
              const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _statusLabel(),
                style: theme.textTheme.bodySmall?.copyWith(color: accent),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leading(Color accent, DownloadProgress progress) {
    if (task.isActive) {
      return SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              value: progress.hasTotal ? progress.fraction : null,
            ),
            if (progress.hasTotal)
              Text(
                '${progress.percent}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(_icon(), color: accent),
    );
  }
}
