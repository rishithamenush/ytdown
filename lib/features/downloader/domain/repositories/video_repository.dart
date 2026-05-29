import '../entities/download_cancel_token.dart';
import '../entities/download_progress.dart';
import '../entities/download_stream.dart';
import '../entities/video_info.dart';

/// Contract for everything the UI needs from a "video source": fetching
/// metadata, listing downloadable variants, and downloading one.
///
/// Domain has no idea this is YouTube — the data layer's implementation
/// could swap to a different provider without the UI knowing.
abstract class VideoRepository {
  /// Fetches the metadata and downloadable variants for [urlOrId] in a single
  /// pass. Combining them lets each source fetch the underlying page/manifest
  /// once (and, where the two pieces come from independent requests, fetch
  /// them in parallel) instead of paying for two sequential round-trips.
  ///
  /// Streams are sorted with the most useful options first (highest quality
  /// video, then audio). Throws on invalid input or network failure.
  Future<VideoBundle> getVideoBundle(String urlOrId);

  /// Downloads [stream] and saves it to public device storage. The returned
  /// future resolves with a user-friendly path to the saved file.
  ///
  /// - [fileName] is the base name (typically the video title).
  /// - [fileSuffix] disambiguates parallel downloads of the same stream.
  /// - [onProgress] fires for every chunk; the repository decides cadence.
  /// - [cancelToken] lets the caller abort mid-stream.
  Future<String> downloadStream({
    required DownloadStream stream,
    required String fileName,
    required String fileSuffix,
    void Function(DownloadProgress progress)? onProgress,
    DownloadCancelToken? cancelToken,
  });

  /// Releases any underlying resources (HTTP clients, etc.).
  void dispose();
}

/// The metadata + downloadable variants for a single video, returned together
/// by [VideoRepository.getVideoBundle].
class VideoBundle {
  const VideoBundle({required this.info, required this.streams});

  final VideoInfo info;
  final List<DownloadStream> streams;
}
