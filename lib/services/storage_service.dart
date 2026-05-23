import 'dart:io';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Saves completed downloads to public device storage (Downloads / Movies).
class StorageService {
  StorageService._();

  static final MediaStore _mediaStore = MediaStore();
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (!Platform.isAndroid || _initialized) return;
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'Vidoory';
    _initialized = true;
  }

  /// Copies [tempFile] into public storage and returns a user-friendly path.
  static Future<String> publishDownload({
    required File tempFile,
    required bool isVideo,
  }) async {
    if (!Platform.isAndroid) {
      final dir = await getApplicationDocumentsDirectory();
      final downloads = Directory('${dir.path}/Downloads');
      if (!downloads.existsSync()) {
        downloads.createSync(recursive: true);
      }
      final dest = File('${downloads.path}/${_fileName(tempFile)}');
      await tempFile.copy(dest.path);
      return dest.path;
    }

    await ensureInitialized();

    final dirType = isVideo ? DirType.video : DirType.download;
    final saveInfo = await _mediaStore.saveFile(
      tempFilePath: tempFile.path,
      dirType: dirType,
      dirName: dirType.defaults,
      relativePath: 'Vidoory',
    );

    if (saveInfo?.uri == null) {
      throw Exception('Could not save file to device storage');
    }

    final filePath = await _mediaStore.getFilePathFromUri(
      uriString: saveInfo!.uri.toString(),
    );

    if (filePath != null && filePath.isNotEmpty) {
      return filePath;
    }

    final folder = isVideo ? 'Movies' : 'Download';
    return '$folder/Vidoory/${_fileName(tempFile)}';
  }

  static String _fileName(File file) =>
      file.path.split(Platform.pathSeparator).last;
}
