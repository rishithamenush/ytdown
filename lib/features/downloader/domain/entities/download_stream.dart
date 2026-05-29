abstract class DownloadStream {
  String get id;
  String get label;
  String get extension;
  bool get isVideo;
  bool get isMerged;
  int? get videoHeight;
  int get estimatedSizeBytes;
}
