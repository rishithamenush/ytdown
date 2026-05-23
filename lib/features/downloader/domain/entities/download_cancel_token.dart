/// Cooperative cancellation handle handed to the repository when a download
/// starts. The UI calls [cancel] to abort; the data layer polls [isCancelled]
/// (or throws via [throwIfCancelled]) between chunks.
///
/// Lives in domain — both the use case and the data layer need it.
class DownloadCancelToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;

  void throwIfCancelled() {
    if (_cancelled) throw const DownloadCancelledException();
  }
}

class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => 'Download cancelled';
}
