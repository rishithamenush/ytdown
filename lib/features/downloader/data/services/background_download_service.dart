import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void _backgroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_DownloadKeepAliveHandler());
}

/// No-op handler. Its only job is to keep the foreground service running so
/// the OS does not kill the main isolate while downloads are in progress.
class _DownloadKeepAliveHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}
}

class BackgroundDownloadService {
  BackgroundDownloadService._();

  static const _channelId = 'vidoory_downloads';
  static bool _initialized = false;
  static bool _running = false;

  static bool get isSupported => Platform.isAndroid || Platform.isIOS;

  static Future<void> ensureInitialized() async {
    if (!isSupported || _initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _channelId,
        channelName: 'Downloads',
        channelDescription: 'Shows progress of active downloads.',
        onlyAlertOnce: true,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _initialized = true;
  }

  /// Request notification permission on Android 13+. Safe to call repeatedly.
  static Future<void> requestPermissions() async {
    if (!Platform.isAndroid) return;
    final notif = await FlutterForegroundTask.checkNotificationPermission();
    if (notif != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  static Future<void> start({
    required String title,
    required String text,
  }) async {
    if (!isSupported) return;
    await ensureInitialized();
    if (_running) {
      await update(title: title, text: text);
      return;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: 561,
      notificationTitle: title,
      notificationText: text,
      callback: _backgroundTaskCallback,
    );
    _running = result is ServiceRequestSuccess;
    if (!_running && kDebugMode) {
      debugPrint('Foreground service failed to start: $result');
    }
  }

  static Future<void> update({
    required String title,
    required String text,
  }) async {
    if (!isSupported || !_running) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  static Future<void> stop() async {
    if (!isSupported || !_running) return;
    await FlutterForegroundTask.stopService();
    _running = false;
  }
}
