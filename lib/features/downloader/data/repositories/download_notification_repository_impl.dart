import '../../domain/repositories/download_notification_repository.dart';
import '../services/background_download_service.dart';

/// Adapter: domain interface → foreground-service singleton.
class DownloadNotificationRepositoryImpl
    implements DownloadNotificationRepository {
  const DownloadNotificationRepositoryImpl();

  @override
  bool get isSupported => BackgroundDownloadService.isSupported;

  @override
  Future<void> showOrUpdate({
    required String title,
    required String text,
  }) {
    return BackgroundDownloadService.start(title: title, text: text);
  }

  @override
  Future<void> hide() => BackgroundDownloadService.stop();

  @override
  Future<void> requestPermission() =>
      BackgroundDownloadService.requestPermissions();
}
