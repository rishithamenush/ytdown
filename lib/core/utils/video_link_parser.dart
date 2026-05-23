/// Supported video platforms and URL detection helpers.
enum VideoSourcePlatform { youtube, tiktok }

abstract final class VideoLinkParser {
  static VideoSourcePlatform? detect(String input) {
    final url = input.trim().toLowerCase();
    if (url.isEmpty) return null;
    if (_isYouTube(url)) return VideoSourcePlatform.youtube;
    if (_isTikTok(url)) return VideoSourcePlatform.tiktok;
    return null;
  }

  static bool _isYouTube(String url) {
    return url.contains('youtube.com/') ||
        url.contains('youtu.be/') ||
        url.contains('youtube-nocookie.com/') ||
        RegExp(r'^[a-z0-9_-]{11}$', caseSensitive: false).hasMatch(url);
  }

  static bool _isTikTok(String url) {
    return url.contains('tiktok.com/') ||
        url.contains('vm.tiktok.com/') ||
        url.contains('vt.tiktok.com/') ||
        url.contains('tiktokv.com/');
  }
}
