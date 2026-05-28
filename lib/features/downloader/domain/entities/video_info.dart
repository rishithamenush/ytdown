import '../../../../core/utils/video_link_parser.dart';

/// Domain entity representing a fetched video's user-facing metadata.
/// Pure Dart — does not depend on any data-source library.
class VideoInfo {
  const VideoInfo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.platform,
    this.duration,
  });

  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final VideoSourcePlatform platform;
  final Duration? duration;

  bool get isTikTok => platform == VideoSourcePlatform.tiktok;
  bool get isYouTube => platform == VideoSourcePlatform.youtube;
  bool get isFacebook => platform == VideoSourcePlatform.facebook;
}
