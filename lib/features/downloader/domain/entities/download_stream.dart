/// Domain entity describing a downloadable variant of a video (a specific
/// quality / audio-only option). The repository returns a list of these for
/// the UI to display; the user picks one and the repository downloads it.
///
/// Concrete implementations live in the data layer and carry the platform-
/// specific stream payload. The domain only cares about display metadata
/// and identity.
abstract class DownloadStream {
  /// Stable identifier within a single fetch — used to look up the actual
  /// stream payload when the user taps to download.
  String get id;

  /// Free-form label used in the active-download UI ("1080p (video + audio)").
  String get label;

  /// File extension that will end up on disk ("mp4", "webm", "m4a").
  String get extension;

  /// True for video options (including merged), false for audio-only.
  bool get isVideo;

  /// True when this option requires muxing a separate video and audio
  /// stream together (typically for HD).
  bool get isMerged;

  /// Vertical resolution in pixels for video options, null for audio.
  int? get videoHeight;

  /// Rough estimated size in bytes used to display "≈12.4 MB" hints.
  int get estimatedSizeBytes;
}
