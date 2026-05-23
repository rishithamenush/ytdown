/// Contract for the OS-level "downloads in progress" notification.
///
/// On phones this becomes a foreground-service notification that keeps the
/// app alive while bytes are flowing; on platforms without that concept it
/// can be a no-op.
abstract class DownloadNotificationRepository {
  /// True if the platform supports a background download notification at all.
  bool get isSupported;

  /// Shows or updates the notification with [title] and [text].
  Future<void> showOrUpdate({required String title, required String text});

  /// Removes the notification (called when no downloads remain active).
  Future<void> hide();

  /// Asks the user for the runtime notification permission on platforms
  /// that require one (Android 13+). Safe to call repeatedly.
  Future<void> requestPermission();
}
