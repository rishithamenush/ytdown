import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeRemoteDataSource {
  YoutubeRemoteDataSource() : _yt = YoutubeExplode();

  final YoutubeExplode _yt;

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
