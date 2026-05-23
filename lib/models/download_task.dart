import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../services/youtube_service.dart';

enum DownloadTaskStatus { downloading, completed, cancelled, failed }

class DownloadTask {
  DownloadTask({
    required this.id,
    required this.videoId,
    required this.videoTitle,
    required this.qualityLabel,
    required this.streamInfo,
    required this.isVideo,
    required this.cancelToken,
  });

  final String id;
  final String videoId;
  final String videoTitle;
  final String qualityLabel;
  final StreamInfo streamInfo;
  final bool isVideo;
  final DownloadCancelToken cancelToken;

  DownloadTaskStatus status = DownloadTaskStatus.downloading;
  DownloadProgress progress = const DownloadProgress(
    fraction: 0,
    downloadedBytes: 0,
    totalBytes: 0,
  );
  String? savedPath;
  String? errorMessage;

  bool get isActive => status == DownloadTaskStatus.downloading;
}
