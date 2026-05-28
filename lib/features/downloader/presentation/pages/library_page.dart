import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';
import '../../domain/entities/download_task.dart';
import '../providers/home_notifier.dart';
import '../widgets/ambient_background.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/download_task_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/top_bar.dart';

/// Library tab — lists in-flight and completed downloads. Tap a finished
/// row to preview the saved file; tap the delete icon to remove the entry
/// (with confirmation).
class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  Future<void> _confirmDismissTask(DownloadTask task) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove this download?',
      message:
          '"${task.videoTitle}" will be removed from your Library. '
          'The saved file in your gallery or music library is not affected.',
      confirmLabel: 'Remove',
      cancelLabel: 'Cancel',
      icon: Icons.delete_outline_rounded,
    );
    if (!mounted || !confirmed) return;
    ref.read(homeNotifierProvider.notifier).dismissTask(task.id);
  }

  Future<void> _confirmClearFinished(int count) async {
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Clear finished downloads?',
      message: count == 1
          ? 'The finished entry will be removed from your Library. '
              'Saved files in your device storage are not affected.'
          : 'All $count finished entries will be removed from your Library. '
              'Saved files in your device storage are not affected.',
      confirmLabel: 'Clear',
      cancelLabel: 'Cancel',
      icon: Icons.cleaning_services_rounded,
    );
    if (!mounted || !confirmed) return;
    ref.read(homeNotifierProvider.notifier).clearFinishedTasks();
  }

  Future<void> _openTaskFile(DownloadTask task) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(homeNotifierProvider.notifier)
        .openTaskFile(task);
    if (!mounted || error == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(error),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(homeNotifierProvider);
    final notifier = ref.read(homeNotifierProvider.notifier);
    final hPad = Responsive.horizontalPadding(context);
    final finishedCount = state.tasks.where((t) => !t.isActive).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
            child: Column(
              children: [
                TopBar(
                  activeCount: state.activeTaskCount,
                  title: 'Library',
                  subtitle: state.tasks.isEmpty
                      ? 'Your saved downloads live here'
                      : '${state.tasks.length} '
                          '${state.tasks.length == 1 ? 'item' : 'items'}',
                ),
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
                        sliver: SliverList.list(
                          children: [
                      if (state.tasks.isEmpty)
                        const _EmptyLibrary()
                      else ...[
                        const SizedBox(height: 12),
                        SectionHeader(
                          icon: Icons.downloading_rounded,
                          title: 'Downloads',
                          trailingAction: finishedCount > 0
                              ? TextButton(
                                  onPressed: () =>
                                      _confirmClearFinished(finishedCount),
                                  child: const Text('Clear finished'),
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),
                        ...state.tasks.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: DownloadTaskTile(
                              task: t,
                              onCancel: () => notifier.cancelTask(t),
                              onDismiss: () => _confirmDismissTask(t),
                              onOpen: () => _openTaskFile(t),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.brandPrimary.withValues(alpha: 0.22),
                  AppTheme.brandPrimary.withValues(alpha: 0.06),
                ],
              ),
              border: Border.all(color: borderColor),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 44,
              color: AppTheme.brandPrimary,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Your Library is empty',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Head to Home, paste a YouTube, TikTok, or Facebook link, '
              'and your downloads will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
