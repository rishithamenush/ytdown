abstract class DownloadNotificationRepository {
  bool get isSupported;

  Future<void> showOrUpdate({required String title, required String text});

  Future<void> hide();

  Future<void> requestPermission();
}
