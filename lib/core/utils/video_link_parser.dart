enum VideoSourcePlatform { youtube, tiktok, facebook, directLink }

abstract final class VideoLinkParser {
  static VideoSourcePlatform? detect(String input) {
    final url = input.trim().toLowerCase();
    if (url.isEmpty) return null;
    if (_isYouTube(url)) return VideoSourcePlatform.youtube;
    if (_isTikTok(url)) return VideoSourcePlatform.tiktok;
    if (_isFacebook(url)) return VideoSourcePlatform.facebook;
    if (_isDirectFileLink(url)) return VideoSourcePlatform.directLink;
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

  static bool _isFacebook(String url) {
    return url.contains('facebook.com/') ||
        url.contains('fb.watch/') ||
        url.contains('fb.com/') ||
        url.contains('m.facebook.com/') ||
        url.contains('web.facebook.com/');
  }

  static bool _isDirectFileLink(String url) {
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return false;
    return fileExtensionOf(uri.path) != null;
  }

  static String? fileExtensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return null;
    final ext = path.substring(dot + 1).toLowerCase();
    return downloadableExtensions.contains(ext) ? ext : null;
  }

  static const Set<String> videoExtensions = {
    'mp4', 'mkv', 'webm', 'mov', 'avi', 'm4v', 'flv', 'ts', 'mpg', 'mpeg',
    '3gp', 'wmv', 'm2ts',
  };

  static const Set<String> audioExtensions = {
    'mp3', 'm4a', 'aac', 'wav', 'ogg', 'oga', 'flac', 'opus', 'wma',
  };

  static const Set<String> otherExtensions = {
    'zip', 'rar', '7z', 'tar', 'gz', 'tgz', 'pdf', 'apk', 'iso', 'img',
    'dmg', 'epub', 'csv', 'txt', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx',
    'png', 'jpg', 'jpeg', 'gif', 'webp', 'svg',
  };

  static final Set<String> downloadableExtensions = {
    ...videoExtensions,
    ...audioExtensions,
    ...otherExtensions,
  };
}
