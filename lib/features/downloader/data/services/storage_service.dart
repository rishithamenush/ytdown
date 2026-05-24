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
    bool isAudio = false,
  }) async {
    if (!await tempFile.exists()) {
      throw Exception('Downloaded file is missing before it could be saved');
    }

    if (!Platform.isAndroid) {
      return _publishOnApple(tempFile);
    }

    await ensureInitialized();

    final dirType = isVideo
        ? DirType.video
        : (isAudio ? DirType.audio : DirType.download);
    final dirName = dirType.defaults;

    // media_store_plus derives the saved filename from the temp path and
    // URI-encodes it on the platform channel. Emoji / non-ASCII names (common
    // on TikTok) can break that on release builds — copy to a safe name first.
    final fileToSave = await _withMediaStoreSafeName(tempFile);

    final saveInfo = await _mediaStore.saveFile(
      tempFilePath: fileToSave.path,
      dirType: dirType,
      dirName: dirName,
      relativePath: 'Vidoory',
    );

    if (saveInfo?.uri == null) {
      throw Exception('Could not save file to device storage');
    }

    // Confirm the entry is visible in MediaStore (do not use isFileUriExist —
    // that only checks SAF document URIs, not content://media/... URIs).
    final verifiedUri = await _mediaStore.getFileUri(
      fileName: saveInfo!.name,
      dirType: dirType,
      dirName: dirName,
      relativePath: 'Vidoory',
    );
    if (verifiedUri == null) {
      throw Exception('Could not save file to device storage');
    }

    final filePath = await _mediaStore.getFilePathFromUri(
      uriString: verifiedUri.toString(),
    );
    if (filePath != null && filePath.isNotEmpty) {
      return filePath;
    }

    // URI exists but legacy DATA column is empty on newer Android — still saved.
    final folder = isVideo
        ? 'Movies'
        : (isAudio ? 'Music' : 'Download');
    return '$folder/Vidoory/${saveInfo.name}';
  }

  /// Returns [file] or a same-directory copy with an ASCII-safe filename.
  static Future<File> _withMediaStoreSafeName(File file) async {
    final originalName = _fileName(file);
    final dot = originalName.lastIndexOf('.');
    final ext = dot >= 0 ? originalName.substring(dot + 1) : '';
    final base = dot >= 0 ? originalName.substring(0, dot) : originalName;
    final safeBase = _mediaStoreSafeName(base);
    final safeName = ext.isNotEmpty ? '$safeBase.$ext' : safeBase;

    if (safeName == originalName) return file;

    final safeFile = File('${file.parent.path}/$safeName');
    await file.copy(safeFile.path);
    return safeFile;
  }

  /// Strips characters that break MediaStore / URI handling on Android.
  static String _mediaStoreSafeName(String name) {
    var safe = name.replaceAll(RegExp(r'[\\/:*?"<>|#]'), '_');
    safe = safe.replaceAll(RegExp(r'[^\x20-\x7E]'), '_');
    safe = safe.replaceAll(RegExp(r'_+'), '_').trim();
    safe = safe.replaceAll(RegExp(r'^\.+|\.+$'), '');
    if (safe.isEmpty) return 'download';
    if (safe.length > 120) safe = safe.substring(0, 120);
    return safe;
  }

  static Future<String> _publishOnApple(File tempFile) async {
    Directory? dir;
    try {
      dir = await getDownloadsDirectory();
    } catch (_) {}
    dir ??= await getApplicationDocumentsDirectory();

    final downloads = Directory('${dir.path}/Vidoory');
    if (!downloads.existsSync()) {
      downloads.createSync(recursive: true);
    }
    final dest = File('${downloads.path}/${_fileName(tempFile)}');
    await tempFile.copy(dest.path);
    return dest.path;
  }

  static String _fileName(File file) =>
      file.path.split(Platform.pathSeparator).last;
}
