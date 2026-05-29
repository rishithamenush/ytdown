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

  bool get hasTotal => totalBytes > 0;

  int get percent => hasTotal ? (fraction * 100).round().clamp(0, 100) : 0;
}
