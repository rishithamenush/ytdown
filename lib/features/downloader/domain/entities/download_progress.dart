/// Snapshot of a download's progress at a moment in time. Immutable —
/// the notifier publishes new instances as bytes arrive.
class DownloadProgress {
  const DownloadProgress({
    required this.fraction,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  const DownloadProgress.initial()
      : fraction = 0,
        downloadedBytes = 0,
        totalBytes = 0;

  final double fraction;
  final int downloadedBytes;
  final int totalBytes;

  /// True when the source reported a total size (so a determinate progress
  /// bar can be drawn). Some streams don't expose this until the request
  /// body starts arriving.
  bool get hasTotal => totalBytes > 0;

  int get percent => hasTotal ? (fraction * 100).round().clamp(0, 100) : 0;
}
