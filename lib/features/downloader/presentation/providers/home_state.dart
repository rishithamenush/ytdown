import '../../domain/entities/download_stream.dart';
import '../../domain/entities/download_task.dart';
import '../../domain/entities/video_info.dart';

class HomeState {
  const HomeState({
    this.video,
    this.streams = const [],
    this.tasks = const [],
    this.loading = false,
    this.error,
  });

  const HomeState.initial() : this();

  final VideoInfo? video;
  final List<DownloadStream> streams;
  final List<DownloadTask> tasks;
  final bool loading;
  final String? error;

  bool get hasFinishedTasks => tasks.any((t) => !t.isActive);
  int get activeTaskCount => tasks.where((t) => t.isActive).length;

  HomeState copyWith({
    VideoInfo? video,
    List<DownloadStream>? streams,
    List<DownloadTask>? tasks,
    bool? loading,
    String? error,
    bool clearVideo = false,
    bool clearError = false,
  }) {
    return HomeState(
      video: clearVideo ? null : (video ?? this.video),
      streams: streams ?? this.streams,
      tasks: tasks ?? this.tasks,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
