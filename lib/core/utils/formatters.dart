/// Shared formatters for byte counts and durations. Pulled out of widgets so
/// the same logic isn't duplicated in three different tiles.
class Formatters {
  Formatters._();

  /// Human-readable byte count, e.g. `1.4 MB`, `860 KB`, `1.20 GB`. Returns
  /// `—` for non-positive values so empty cells don't read as `0 B`.
  static String bytes(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Same as [bytes] but uses `0 B` instead of `—` for zero. Use in
  /// download progress where 0-bytes-downloaded is a valid state.
  static String bytesProgress(int bytes) {
    if (bytes <= 0) return '0 B';
    return Formatters.bytes(bytes);
  }

  /// `mm:ss` or `h:mm:ss` formatting. Returns an empty string for null so
  /// callers can hide the badge when duration is unknown.
  static String duration(Duration? d) {
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
}
