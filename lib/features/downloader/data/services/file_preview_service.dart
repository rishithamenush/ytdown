import 'dart:io';

import 'package:open_filex/open_filex.dart';

/// Opens a downloaded file with the device's default handler (gallery,
/// music player, etc.). Returns a user-friendly error string when the open
/// fails, or null on success.
class FilePreviewService {
  const FilePreviewService();

  Future<String?> open(String path) async {
    if (path.isEmpty) return 'No file path available for this download.';

    // Reject the synthesized label-style paths emitted by StorageService when
    // MediaStore's legacy DATA column is empty (e.g. "Movies/Vidoory/foo.mp4").
    // OpenFilex needs a real absolute path or content URI.
    final looksAbsolute = path.startsWith('/') ||
        path.startsWith('content://') ||
        path.startsWith('file://');
    if (!looksAbsolute) {
      return 'Saved to $path — open it from your device gallery or files app.';
    }

    if (path.startsWith('/') && !await File(path).exists()) {
      return 'File no longer exists. It may have been moved or deleted.';
    }

    final result = await OpenFilex.open(path);
    switch (result.type) {
      case ResultType.done:
        return null;
      case ResultType.noAppToOpen:
        return 'No app on this device can open this file.';
      case ResultType.permissionDenied:
        return 'Permission denied while opening the file.';
      case ResultType.fileNotFound:
        return 'File not found at $path.';
      case ResultType.error:
        return result.message.isEmpty
            ? 'Could not open the file.'
            : result.message;
    }
  }
}
