import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Thin wrapper around [YoutubeExplode] so the rest of the data layer (and
/// every higher layer) does not import the youtube_explode_dart package
/// directly. Swapping providers later only requires touching this file.
class YoutubeRemoteDataSource {
  YoutubeRemoteDataSource() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

  // Multiple clients are tried in order — some manifests only resolve via
  // the Android VR / Safari clients depending on what YouTube returns today.
  static final List<YoutubeApiClient> _manifestClients = [
    YoutubeApiClient.androidVr,
    YoutubeApiClient.safari,
    YoutubeApiClient.ios,
    YoutubeApiClient.android,
  ];

  Future<Video> getVideo(String urlOrId) {
    return _yt.videos.get(VideoId(urlOrId));
  }

  Future<StreamManifest> getManifest(String urlOrId) {
    return _yt.videos.streamsClient.getManifest(
      VideoId(urlOrId),
      ytClients: _manifestClients,
    );
  }

  Stream<List<int>> openStream(StreamInfo info) {
    return _yt.videos.streamsClient.get(info);
  }

  void dispose() {
    _yt.close();
  }
}
