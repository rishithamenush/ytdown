import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/entities/download_task.dart';

/// Persists finished download tasks to a JSON file so the Downloads list
/// survives app restarts. Active (in-flight) downloads are not persisted —
/// they would be unresumable on next launch anyway.
class DownloadHistoryService {
  DownloadHistoryService();

  static const _fileName = 'download_history.json';
  static const _schemaVersion = 1;

  // Serialize writes so two near-simultaneous state changes (e.g. a download
  // finishing while the user taps Dismiss) can't truncate each other.
  Future<void> _writeQueue = Future.value();

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<DownloadTask>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      final tasks = decoded['tasks'];
      if (tasks is! List) return const [];
      return tasks
          .whereType<Map>()
          .map((m) => DownloadTask.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      // Corrupt history shouldn't block the app — start with an empty list.
      return const [];
    }
  }

  /// Persists only the non-active tasks. Caller can pass the full task list;
  /// active ones are filtered out so an in-flight download isn't frozen on
  /// disk as "downloading" if the process dies right after this write.
  Future<void> save(List<DownloadTask> tasks) {
    final snapshot = tasks
        .where((t) => !t.isActive)
        .map((t) => t.toJson())
        .toList(growable: false);
    final next = _writeQueue.then((_) => _writeNow(snapshot));
    // Swallow errors in the chained future so one bad write doesn't poison
    // every subsequent save call.
    _writeQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _writeNow(List<Map<String, dynamic>> snapshot) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    final payload = jsonEncode({
      'version': _schemaVersion,
      'tasks': snapshot,
    });
    await tmp.writeAsString(payload, flush: true);
    // Atomic-ish replace: rename is single-syscall on the same filesystem,
    // so a crash mid-save can't leave a half-written history file.
    await tmp.rename(file.path);
  }
}
