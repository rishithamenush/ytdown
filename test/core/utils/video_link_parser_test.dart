import 'package:flutter_test/flutter_test.dart';
import 'package:vidoory/core/utils/video_link_parser.dart';

void main() {
  group('VideoLinkParser.detect', () {
    test('recognises a direct MP4 URL (file-examples sample)', () {
      const url =
          'https://file-examples.com/storage/fe4da8de496a1985d944cf8/'
          '2017/04/file_example_MP4_1920_18MG.mp4';
      expect(VideoLinkParser.detect(url), VideoSourcePlatform.directLink);
    });

    test('recognises direct links case-insensitively', () {
      expect(
        VideoLinkParser.detect('HTTPS://CDN.EXAMPLE.COM/CLIP.MP4'),
        VideoSourcePlatform.directLink,
      );
    });

    test('prefers YouTube over a path that happens to end in .mp4', () {
      expect(
        VideoLinkParser.detect('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
        VideoSourcePlatform.youtube,
      );
    });

    test('returns null for http URLs without a known file extension', () {
      expect(
        VideoLinkParser.detect('https://example.com/page'),
        isNull,
      );
    });
  });

  group('VideoLinkParser.fileExtensionOf', () {
    test('extracts mp4 from a path', () {
      expect(
        VideoLinkParser.fileExtensionOf(
          '/2017/04/file_example_MP4_1920_18MG.mp4',
        ),
        'mp4',
      );
    });
  });
}
