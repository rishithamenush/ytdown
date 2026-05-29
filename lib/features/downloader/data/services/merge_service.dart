import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';

class MergeService {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    await FFmpegKitConfig.init();
    _initialized = true;
  }

  static Future<void> mergeVideoAndAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    await ensureInitialized();

    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-i',
      videoPath,
      '-i',
      audioPath,
      '-map',
      '0:v:0',
      '-map',
      '1:a:0',
      '-c:v',
      'copy',
      '-c:a',
      'aac',
      '-b:a',
      '192k',
      '-shortest',
      '-movflags',
      '+faststart',
      outputPath,
    ]);

    final returnCode = await session.getReturnCode();
    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      final fail = await session.getFailStackTrace();
      throw Exception(
        'Could not merge video and audio.'
        '${output != null ? ' $output' : ''}'
        '${fail != null ? ' $fail' : ''}',
      );
    }
  }
}
