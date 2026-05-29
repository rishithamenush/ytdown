import 'dart:async';
import 'dart:io';

import 'package:media_store_plus/media_store_plus.dart';
import 'package:path_provider/path_provider.dart';

class StorageService {
  StorageService._();

  static final MediaStore _mediaStore = MediaStore();
  static bool _initialized = false;

  // MediaStore platform-channel calls have been observed to hang on certain
  // Android versions when the file's MIME doesn't match the dir's table
  // (e.g. .webm audio into Audio). A timeout lets us fall back instead of
  // leaving the UI stuck at 100% forever.
  static const _mediaStoreCallTimeout = Duration(seconds: 12);

  static Future<void> ensureInitialized() async {
    if (!Platform.isAndroid || _initialized) return;
    await MediaStore.ensureInitialized();
    MediaStore.appFolder = 'Vidoory';
    _initialized = true;
  }

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

    // media_store_plus URI-encodes the filename; emoji/non-ASCII break on
    // release builds. Audio also needs mp4→m4a / webm→weba remapping.
    final fileToSave =
        await _withMediaStoreSafeName(tempFile, isAudio: isAudio);

    final primary = isVideo
        ? DirType.video
        : (isAudio ? DirType.audio : DirType.download);

    final saved = await _trySaveInto(fileToSave, primary);
    if (saved != null) return saved;

    // Audio/video table refused the file (mp4 audio on old devices, exotic
    // webm container, etc.). Fall back to the Download dir, which has no
    // MIME-vs-table restriction. The file still lands in Download/Vidoory
    // and is fully accessible — just not indexed as Music/Movies.
    if (primary != DirType.download) {
      final fallback = await _trySaveInto(fileToSave, DirType.download);
      if (fallback != null) return fallback;
    }

    throw Exception('Could not save file to device storage');
  }

  static Future<String?> _trySaveInto(File file, DirType dirType) async {
    final dirName = dirType.defaults;
    try {
      final saveInfo = await _mediaStore
          .saveFile(
            tempFilePath: file.path,
            dirType: dirType,
            dirName: dirName,
            relativePath: 'Vidoory',
          )
          .timeout(_mediaStoreCallTimeout);

      if (saveInfo?.uri == null) return null;

      final verifiedUri = await _mediaStore
          .getFileUri(
            fileName: saveInfo!.name,
            dirType: dirType,
            dirName: dirName,
            relativePath: 'Vidoory',
          )
          .timeout(_mediaStoreCallTimeout);
      if (verifiedUri == null) return null;

      final filePath = await _mediaStore
          .getFilePathFromUri(uriString: verifiedUri.toString())
          .timeout(_mediaStoreCallTimeout);
      if (filePath != null && filePath.isNotEmpty) return filePath;

      // URI exists but legacy DATA column is empty on newer Android — still
      // saved. Synthesize a friendly label from the dir type.
      return '${_topFolderFor(dirType)}/Vidoory/${saveInfo.name}';
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  static String _topFolderFor(DirType dir) {
    if (dir == DirType.video) return 'Movies';
    if (dir == DirType.audio) return 'Music';
    return 'Download';
  }

  static Future<File> _withMediaStoreSafeName(
    File file, {
    bool isAudio = false,
  }) async {
    final originalName = _fileName(file);
    final dot = originalName.lastIndexOf('.');
    var ext = dot >= 0 ? originalName.substring(dot + 1) : '';
    final base = dot >= 0 ? originalName.substring(0, dot) : originalName;
    final safeBase = _mediaStoreSafeName(base);
    if (isAudio) ext = _audioFriendlyExtension(ext);
    final safeName = ext.isNotEmpty ? '$safeBase.$ext' : safeBase;

    if (safeName == originalName) return file;

    final safeFile = File('${file.parent.path}/$safeName');
    await file.copy(safeFile.path);
    return safeFile;
  }

  // mp4/webm are video/* MIME; the Audio table rejects them. m4a/weba carry audio/* MIME.
  static String _audioFriendlyExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'mp4':
      case 'm4v':
        return 'm4a';
      case 'webm':
        return 'weba';
      default:
        return ext;
    }
  }

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
