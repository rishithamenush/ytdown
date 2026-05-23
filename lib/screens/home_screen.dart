import 'dart:async';

import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/download_task.dart';
import '../services/background_download_service.dart';
import '../services/youtube_service.dart';

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

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
      setState(() => _error = 'Paste a YouTube URL or video ID');
      return;
    }

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

  Widget _buildTaskCard(ThemeData theme, DownloadTask task) {
    final progress = task.progress;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: switch (task.status) {
        DownloadTaskStatus.completed =>
          theme.colorScheme.tertiaryContainer.withValues(alpha: 0.4),
        DownloadTaskStatus.failed =>
          theme.colorScheme.errorContainer.withValues(alpha: 0.4),
        DownloadTaskStatus.cancelled =>
          theme.colorScheme.surfaceContainerHighest,
        DownloadTaskStatus.downloading =>
          theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        value: progress.hasTotal ? progress.fraction : null,
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 10, top: 2),
                    child: Icon(
                      switch (task.status) {
                        DownloadTaskStatus.completed => Icons.check_circle,
                        DownloadTaskStatus.cancelled => Icons.cancel,
                        DownloadTaskStatus.failed => Icons.error_outline,
                        DownloadTaskStatus.downloading => Icons.download,
                      },
                      size: 22,
                      color: switch (task.status) {
                        DownloadTaskStatus.completed =>
                          theme.colorScheme.primary,
                        DownloadTaskStatus.cancelled =>
                          theme.colorScheme.onSurfaceVariant,
                        DownloadTaskStatus.failed => theme.colorScheme.error,
                        DownloadTaskStatus.downloading =>
                          theme.colorScheme.primary,
                      },
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.videoTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        task.qualityLabel,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (task.isActive && progress.hasTotal)
                  Text(
                    '${progress.percent}%',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    if (task.isActive) {
                      _cancelTask(task);
                    } else {
                      _removeTask(task.id);
                    }
                  },
                  tooltip: task.isActive ? 'Cancel' : 'Dismiss',
                ),
              ],
            ),
            if (task.isActive) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progress.hasTotal ? progress.fraction : null,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                progress.hasTotal
                    ? '${_formatBytes(progress.downloadedBytes)} / ${_formatBytes(progress.totalBytes)}'
                    : '${_formatBytes(progress.downloadedBytes)} downloaded',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (task.status == DownloadTaskStatus.completed &&
                task.savedPath != null) ...[
              const SizedBox(height: 6),
              Text(
                task.isVideo
                    ? 'Saved to Movies/YTDown'
                    : 'Saved to Download/YTDown',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 12,
                ),
              ),
              Text(
                task.savedPath!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (task.status == DownloadTaskStatus.cancelled) ...[
              const SizedBox(height: 4),
              Text(
                'Cancelled',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
            if (task.status == DownloadTaskStatus.failed) ...[
              const SizedBox(height: 4),
              Text(
                task.errorMessage ?? 'Download failed',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeCount =
        _downloadTasks.where((t) => t.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('YT Down'),
        centerTitle: true,
        actions: [
          if (activeCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Chip(
                  label: Text('$activeCount downloading'),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'YouTube URL',
              hintText: 'https://youtube.com/watch?v=…',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => _urlController.clear(),
              ),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _fetchVideo(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _fetchVideo,
            icon: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(_loading ? 'Loading…' : 'Get video'),
          ),
          if (_downloadTasks.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Downloads',
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (_downloadTasks.any((t) => !t.isActive))
                  TextButton(
                    onPressed: () {
                      setState(
                        () => _downloadTasks.removeWhere((t) => !t.isActive),
                      );
                    },
                    child: const Text('Clear finished'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ..._downloadTasks.map((t) => _buildTaskCard(theme, t)),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (_video != null) ...[
            const SizedBox(height: 24),
            Text(
              _video!.title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _video!.author,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Choose quality',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tap multiple qualities to download at the same time.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_streams.length, (i) {
              final option = _streams[i];
              final task = _taskForStream(i);
              final downloading = task?.isActive ?? false;
              final itemProgress = downloading ? task!.progress : null;

              return Card(
                child: Column(
                  children: [
                    ListTile(
                      title: Text(option.label),
                      subtitle: Text('.${option.extension}'),
                      trailing: downloading
                          ? SizedBox(
                              width: 40,
                              height: 40,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    strokeWidth: 3,
                                    value: itemProgress?.hasTotal == true
                                        ? itemProgress!.fraction
                                        : null,
                                  ),
                                  if (itemProgress?.hasTotal == true)
                                    Text(
                                      '${itemProgress!.percent}',
                                      style: theme.textTheme.labelSmall,
                                    ),
                                ],
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.download),
                              onPressed: () => _download(i),
                            ),
                    ),
                    if (downloading && itemProgress != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              minHeight: 6,
                              value: itemProgress.hasTotal
                                  ? itemProgress.fraction
                                  : null,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              itemProgress.hasTotal
                                  ? '${itemProgress.percent}% · ${_formatBytes(itemProgress.downloadedBytes)} / ${_formatBytes(itemProgress.totalBytes)}'
                                  : '${_formatBytes(itemProgress.downloadedBytes)} downloaded',
                              style: theme.textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              'HD options download video and audio separately, then merge '
              '(may take longer). 360p quick uses a single stream without merge.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
