import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_stream.dart';
import '../../domain/entities/download_task.dart';

class QualityTile extends StatelessWidget {
  const QualityTile({
    super.key,
    required this.stream,
    required this.activeTask,
    required this.completedTask,
    required this.onTap,
    required this.onOpenCompleted,
  });

  final DownloadStream stream;
  final DownloadTask? activeTask;
  final DownloadTask? completedTask;
  final VoidCallback? onTap;
  final VoidCallback onOpenCompleted;

  bool get _isAudio => !stream.isVideo;

  String get _badge {
    if (_isAudio) return 'AUDIO';
    final h = stream.videoHeight;
    if (h == null) return 'SD';
    if (h >= 2160) return '4K';
    if (h >= 1440) return '2K';
    if (h >= 1080) return 'FHD';
    if (h >= 720) return 'HD';
    return 'SD';
  }

  IconData get _icon =>
      _isAudio ? Icons.graphic_eq_rounded : Icons.movie_filter_rounded;

  Color _badgeColor() {
    if (_isAudio) return AppTheme.brandAccent;
    final h = stream.videoHeight ?? 0;
    if (h >= 2160) return const Color(0xFFFFB020);
    if (h >= 1080) return AppTheme.brandPrimary;
    return AppTheme.brandSecondary;
  }

  String _title() {
    if (_isAudio) return 'Audio only';
    final h = stream.videoHeight;
    if (h == null) return stream.label;
    return '${h}p';
  }

  String _subtitle() {
    final size = Formatters.bytes(stream.estimatedSizeBytes);
    final ext = stream.extension;
    if (stream.isMerged) {
      return 'Video + audio merge · .$ext · ≈$size';
    }
    if (_isAudio) {
      return 'Best audio · .$ext · ≈$size';
    }
    return 'Quick (no merge) · .$ext · ≈$size';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final downloading = activeTask != null;
    final done = completedTask != null;
    final progress = activeTask?.progress;
    final canPreview = done && (completedTask!.savedPath?.isNotEmpty ?? false);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: canPreview ? onOpenCompleted : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(13),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _badgeColor().withValues(alpha: 0.22),
                          _badgeColor().withValues(alpha: 0.08),
                        ],
                      ),
                      border: Border.all(
                        color: _badgeColor().withValues(alpha: 0.35),
                      ),
                    ),
                    child: Icon(_icon, color: _badgeColor(), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_title(), style: theme.textTheme.titleMedium),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: _badgeColor().withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _badge,
                                style: GoogleFonts.plusJakartaSans(
                                  color: _badgeColor(),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(_subtitle(), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _trailing(theme, downloading, done, progress),
                ],
              ),
              if (downloading && progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress.hasTotal ? progress.fraction : null,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  progress.hasTotal
                      ? '${progress.percent}% · ${Formatters.bytes(progress.downloadedBytes)} / ${Formatters.bytes(progress.totalBytes)}'
                      : '${Formatters.bytes(progress.downloadedBytes)} downloaded',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _trailing(
    ThemeData theme,
    bool downloading,
    bool done,
    DownloadProgress? progress,
  ) {
    if (downloading) {
      return SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              value: progress?.hasTotal == true ? progress!.fraction : null,
            ),
            if (progress?.hasTotal == true)
              Text(
                '${progress!.percent}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
      );
    }
    if (done) {
      final canPreview = completedTask!.savedPath?.isNotEmpty ?? false;
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.brandSecondary.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(
          canPreview
              ? Icons.play_arrow_rounded
              : Icons.check_rounded,
          color: AppTheme.brandSecondary,
        ),
      );
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: AppTheme.downloadGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.downloadGreen.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Icon(Icons.download_rounded, color: Colors.white),
    );
  }
}
