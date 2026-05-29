import 'package:dio/dio.dart';

class TiktokRemoteDataSource {
  TiktokRemoteDataSource({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _endpoint = 'https://www.tikwm.com/api/';

  Future<TiktokVideoData> getVideo(String url) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _endpoint,
      queryParameters: {'url': url.trim(), 'hd': 1},
      options: Options(
        responseType: ResponseType.json,
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                  '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        },
      ),
    );

    final body = response.data;
    if (body == null) {
      throw StateError('TikTok service returned an empty response');
    }

    final code = body['code'];
    if (code != 0) {
      final msg = body['msg']?.toString() ?? 'unknown error';
      throw StateError('TikTok service refused this link: $msg');
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('TikTok service returned an unexpected payload');
    }

    return TiktokVideoData.fromJson(data);
  }
}

class TiktokVideoData {
  const TiktokVideoData({
    required this.id,
    required this.title,
    required this.author,
    required this.cover,
    required this.duration,
    required this.noWatermarkUrl,
    required this.watermarkUrl,
    required this.audioUrl,
    required this.noWatermarkBytes,
    required this.watermarkBytes,
  });

  factory TiktokVideoData.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final authorName = (author is Map<String, dynamic>)
        ? (author['nickname']?.toString().trim().isNotEmpty == true
            ? author['nickname'].toString()
            : author['unique_id']?.toString() ?? 'TikTok')
        : 'TikTok';

    // TikWM returns relative paths like "/video/play/..." that need the host
    // prefix; absolute https URLs come through unchanged.
    String full(String? path) {
      if (path == null || path.isEmpty) return '';
      if (path.startsWith('http')) return path;
      return 'https://www.tikwm.com$path';
    }

    return TiktokVideoData(
      id: json['id']?.toString() ?? '',
      title: (json['title']?.toString() ?? '').trim(),
      author: authorName,
      cover: full(json['cover']?.toString()),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      noWatermarkUrl: full(json['hdplay']?.toString() ?? json['play']?.toString()),
      watermarkUrl: full(json['wmplay']?.toString()),
      audioUrl: full(json['music']?.toString()),
      noWatermarkBytes:
          (json['hd_size'] as num?)?.toInt() ?? (json['size'] as num?)?.toInt() ?? 0,
      watermarkBytes: (json['wm_size'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String title;
  final String author;
  final String cover;
  final int duration; // seconds
  final String noWatermarkUrl;
  final String watermarkUrl;
  final String audioUrl;
  final int noWatermarkBytes;
  final int watermarkBytes;
}
