/// Domain entity representing a fetched video's user-facing metadata.
/// Pure Dart — does not depend on any data-source library.
class VideoInfo {
  const VideoInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    this.duration,
  });

  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final Duration? duration;
}
