import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/user_facing_error.dart';
import '../../data/services/download_history_service.dart';
import '../../data/services/file_preview_service.dart';
import '../../domain/entities/download_cancel_token.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_stream.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/repositories/download_notification_repository.dart';
import '../../domain/usecases/download_stream_use_case.dart';
import '../../domain/usecases/fetch_video_info.dart';
import 'home_state.dart';
import 'providers.dart';

class HomeNotifier extends Notifier<HomeState> {
  late final FetchVideoInfo _fetchVideoInfo;
  late final DownloadStreamUseCase _downloadStream;
  late final DownloadNotificationRepository _notifications;
  late final DownloadHistoryService _history;
  late final FilePreviewService _filePreview;

  int _taskIdCounter = 0;
  DateTime _lastNotificationUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  HomeState build() {
    _fetchVideoInfo = ref.read(fetchVideoInfoProvider);
    _downloadStream = ref.read(downloadStreamUseCaseProvider);
    _notifications = ref.read(downloadNotificationRepositoryProvider);
    _history = ref.read(downloadHistoryServiceProvider);
    _filePreview = ref.read(filePreviewServiceProvider);
    unawaited(_restoreHistory());
    return const HomeState.initial();
  }

  Future<void> _restoreHistory() async {
    final restored = await _history.load();
    if (restored.isEmpty) return;
    for (final t in restored) {
      final asInt = int.tryParse(t.id);
      if (asInt != null && asInt > _taskIdCounter) _taskIdCounter = asInt;
    }
    state = state.copyWith(tasks: [...state.tasks, ...restored]);
  }

  Future<void> fetchVideo(String urlOrId) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _fetchVideoInfo(urlOrId);
      state = state.copyWith(
        video: result.info,
        streams: result.streams,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        clearVideo: true,
        streams: [],
        error: userFacingError(e),
      );
    }
  }

  void clearSearch() {
    state = state.copyWith(
      clearVideo: true,
      streams: [],
      clearError: true,
    );
  }

  Future<void> startDownload(DownloadStream stream) async {
    final video = state.video;
    if (video == null) return;
    if (_alreadyDownloading(video.id, stream.id)) return;

    await _notifications.requestPermission();

    final task = DownloadTask(
      id: '${++_taskIdCounter}',
      videoId: video.id,
      videoTitle: video.title,
      qualityLabel: stream.label,
      streamId: stream.id,
      isVideo: stream.isVideo,
      cancelToken: DownloadCancelToken(),
    );

    state = state.copyWith(
      tasks: [task, ...state.tasks],
      clearError: true,
    );
    _syncForegroundNotification(force: true);

    unawaited(_runDownload(task, stream));
  }

  void cancelTask(DownloadTask task) => task.cancelToken.cancel();

  Future<String?> openTaskFile(DownloadTask task) {
    if (task.status != DownloadTaskStatus.completed) {
      return Future.value('This download is not finished yet.');
    }
    final path = task.savedPath;
    if (path == null || path.isEmpty) {
      return Future.value('No saved file is available for this download.');
    }
    return _filePreview.open(path);
  }

  void dismissTask(String id) {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );
    _persistHistory();
  }

  void clearFinishedTasks() {
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.isActive).toList(),
    );
    _persistHistory();
  }

  DownloadTask? taskForStream(DownloadStream stream) {
    final videoId = state.video?.id;
    if (videoId == null) return null;
    for (final t in state.tasks) {
      if (t.videoId == videoId && t.streamId == stream.id) return t;
    }
    return null;
  }

  bool _alreadyDownloading(String videoId, String streamId) {
    return state.tasks.any((t) =>
        t.videoId == videoId && t.streamId == streamId && t.isActive);
  }

  Future<void> _runDownload(DownloadTask task, DownloadStream stream) async {
    try {
      final path = await _downloadStream(
        stream: stream,
        fileName: task.videoTitle,
        fileSuffix: task.id,
        cancelToken: task.cancelToken,
        onProgress: (p) {
          task.progress = p;
          _publishTaskUpdate();
          _syncForegroundNotification();
        },
      );

      task.status = DownloadTaskStatus.completed;
      task.savedPath = path;
      _publishTaskUpdate();
    } on DownloadCancelledException {
      task.status = DownloadTaskStatus.cancelled;
      _publishTaskUpdate();
    } catch (e) {
      task.status = DownloadTaskStatus.failed;
      task.errorMessage = e.toString();
      _publishTaskUpdate();
    } finally {
      _syncForegroundNotification(force: true);
      _persistHistory();
    }
  }

  void _persistHistory() {
    unawaited(_history.save(state.tasks));
  }

  void _publishTaskUpdate() {
    state = state.copyWith(tasks: List.of(state.tasks));
  }

  void _syncForegroundNotification({bool force = false}) {
    if (!_notifications.isSupported) return;

    final active = state.tasks.where((t) => t.isActive).toList();
    if (active.isEmpty) {
      _lastNotificationUpdate = DateTime.fromMillisecondsSinceEpoch(0);
      unawaited(_notifications.hide());
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
      final avg =
          active.fold<double>(0, (sum, t) => sum + t.progress.fraction) /
              active.length;
      text = '${(avg * 100).round()}% overall';
    } else {
      text = 'In progress…';
    }

    unawaited(_notifications.showOrUpdate(title: title, text: text));
  }
}

final homeNotifierProvider = NotifierProvider<HomeNotifier, HomeState>(() {
  return HomeNotifier();
});

// Re-export DownloadProgress so widgets only need to import the providers
// barrel — keeps the presentation layer's import surface small.
typedef HomeDownloadProgress = DownloadProgress;
