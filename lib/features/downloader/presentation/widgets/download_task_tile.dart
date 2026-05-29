import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/download_task.dart';
import 'app_selection_checkbox.dart';

class DownloadTaskTile extends StatelessWidget {
  const DownloadTaskTile({
    super.key,
    required this.task,
    required this.onCancel,
    required this.onDismiss,
    required this.onOpen,
    this.selectionMode = false,
    this.selected = false,
    this.onSelectionToggle,
    this.onLongPress,
  });

  final DownloadTask task;
  final VoidCallback onCancel;
  final VoidCallback onDismiss;
  final VoidCallback onOpen;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelectionToggle;
  final VoidCallback? onLongPress;

  bool get _canOpen =>
      task.status == DownloadTaskStatus.completed &&
      (task.savedPath?.isNotEmpty ?? false);

  Color _accent(ThemeData theme) {
    switch (task.status) {
      case DownloadTaskStatus.completed:
        return AppTheme.brandSecondary;
      case DownloadTaskStatus.failed:
        return theme.colorScheme.error;
      case DownloadTaskStatus.cancelled:
        return theme.colorScheme.onSurfaceVariant;
      case DownloadTaskStatus.downloading:
        return AppTheme.brandPrimary;
    }
  }

  IconData _icon() {
    switch (task.status) {
      case DownloadTaskStatus.completed:
        return Icons.check_circle_rounded;
      case DownloadTaskStatus.failed:
        return Icons.error_outline_rounded;
      case DownloadTaskStatus.cancelled:
        return Icons.cancel_rounded;
      case DownloadTaskStatus.downloading:
        return Icons.download_rounded;
    }
  }

  String _statusLabel() {
    switch (task.status) {
      case DownloadTaskStatus.completed:
        return 'Saved · ${task.savedLocationLabel}';
      case DownloadTaskStatus.failed:
        return task.errorMessage ?? 'Download failed';
      case DownloadTaskStatus.cancelled:
        return 'Cancelled';
      case DownloadTaskStatus.downloading:
        return task.progress.hasTotal
            ? '${Formatters.bytesProgress(task.progress.downloadedBytes)} / ${Formatters.bytesProgress(task.progress.totalBytes)}'
            : '${Formatters.bytesProgress(task.progress.downloadedBytes)} downloaded';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = task.progress;
    final accent = _accent(theme);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: selectionMode
            ? onSelectionToggle
            : (_canOpen ? onOpen : null),
        onLongPress: selectionMode ? null : onLongPress,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (selectionMode)
                  SizedBox(
                    width: 42,
                    height: 42,
                    child: Center(
                      child: AppSelectionCheckbox(
                        selected: selected,
                        onChanged: (_) => onSelectionToggle?.call(),
                        size: 28,
                      ),
                    ),
                  )
                else
                  _leading(accent, progress),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.videoTitle,
                        style: theme.textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.qualityLabel,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!selectionMode)
                  IconButton(
                    icon: Icon(
                      task.isActive
                          ? Icons.close_rounded
                          : Icons.delete_outline_rounded,
                      size: 20,
                    ),
                    tooltip: task.isActive ? 'Cancel' : 'Dismiss',
                    onPressed: task.isActive ? onCancel : onDismiss,
                  ),
              ],
            ),
            if (task.isActive) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: progress.hasTotal ? progress.fraction : null,
                ),
              ),
              const SizedBox(height: 6),
            ] else
              const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _statusLabel(),
                      style: theme.textTheme.bodySmall?.copyWith(color: accent),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_canOpen && !selectionMode) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tap to preview',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _leading(Color accent, DownloadProgress progress) {
    if (task.isActive) {
      return SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              strokeWidth: 3,
              value: progress.hasTotal ? progress.fraction : null,
            ),
            if (progress.hasTotal)
              Text(
                '${progress.percent}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(_icon(), color: accent),
    );
  }
}
