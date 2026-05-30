import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/responsive.dart';
import '../../domain/entities/download_task.dart';
import '../providers/home_notifier.dart';
import '../widgets/ambient_background.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/download_task_tile.dart';
import '../widgets/section_header.dart';
import '../widgets/top_bar.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});

  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  void _enterSelectionMode(String taskId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..add(taskId);
    });
  }

  void _toggleSelection(String taskId) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(taskId)) {
        _selectedIds.remove(taskId);
        if (_selectedIds.isEmpty) _selectionMode = false;
      } else {
        _selectedIds.add(taskId);
      }
    });
  }

  void _selectAll(List<DownloadTask> tasks) {
    HapticFeedback.lightImpact();
    setState(() {
      _selectionMode = true;
      _selectedIds
        ..clear()
        ..addAll(tasks.map((t) => t.id));
    });
  }

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

  Future<void> _confirmRemoveSelected(List<DownloadTask> tasks) async {
    final selected = tasks.where((t) => _selectedIds.contains(t.id)).toList();
    if (selected.isEmpty) return;

    final activeCount = selected.where((t) => t.isActive).length;
    final finishedCount = selected.length - activeCount;

    final parts = <String>[];
    if (finishedCount > 0) {
      parts.add(
        finishedCount == 1
            ? '1 finished entry'
            : '$finishedCount finished entries',
      );
    }
    if (activeCount > 0) {
      parts.add(
        activeCount == 1 ? '1 active download' : '$activeCount active downloads',
      );
    }
    final summary = parts.join(' and ');

    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Remove selected?',
      message:
          '$summary will be removed from your Library. '
          'Saved files on your device are not affected.',
      confirmLabel: 'Remove',
      cancelLabel: 'Cancel',
      icon: Icons.delete_outline_rounded,
    );
    if (!mounted || !confirmed) return;

    final notifier = ref.read(homeNotifierProvider.notifier);
    notifier.cancelTasks(selected.where((t) => t.isActive));
    notifier.dismissTasks(_selectedIds);
    _exitSelectionMode();
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
    final selectedCount = _selectedIds.length;
    final allSelected =
        state.tasks.isNotEmpty && selectedCount == state.tasks.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
            child: Column(
              children: [
                if (_selectionMode)
                  _SelectionTopBar(
                    selectedCount: selectedCount,
                    onCancel: _exitSelectionMode,
                    onSelectAll: allSelected
                        ? _exitSelectionMode
                        : () => _selectAll(state.tasks),
                    selectAllLabel: allSelected ? 'Deselect all' : 'Select all',
                  )
                else
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
                        padding: EdgeInsets.fromLTRB(
                          hPad,
                          8,
                          hPad,
                          _selectionMode && selectedCount > 0 ? 100 : 32,
                        ),
                        sliver: SliverList.list(
                          children: [
                            if (state.tasks.isEmpty)
                              const _EmptyLibrary()
                            else ...[
                              const SizedBox(height: 12),
                              SectionHeader(
                                icon: Icons.downloading_rounded,
                                title: 'Downloads',
                                trailingAction: _selectionMode
                                    ? null
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextButton(
                                            onPressed: () =>
                                                _selectAll(state.tasks),
                                            child: const Text('Select'),
                                          ),
                                          if (finishedCount > 0)
                                            TextButton(
                                              onPressed: () =>
                                                  _confirmClearFinished(
                                                finishedCount,
                                              ),
                                              child: const Text(
                                                'Clear finished',
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                              const SizedBox(height: 10),
                              ...state.tasks.map(
                                (t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: DownloadTaskTile(
                                    task: t,
                                    selectionMode: _selectionMode,
                                    selected: _selectedIds.contains(t.id),
                                    onSelectionToggle: () =>
                                        _toggleSelection(t.id),
                                    onLongPress: () =>
                                        _enterSelectionMode(t.id),
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
          if (_selectionMode && selectedCount > 0)
            Positioned(
              left: hPad,
              right: hPad,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _SelectionActionBar(
                  count: selectedCount,
                  onDelete: () => _confirmRemoveSelected(state.tasks),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectionTopBar extends StatelessWidget {
  const _SelectionTopBar({
    required this.selectedCount,
    required this.onCancel,
    required this.onSelectAll,
    required this.selectAllLabel,
  });

  final int selectedCount;
  final VoidCallback onCancel;
  final VoidCallback onSelectAll;
  final String selectAllLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hPad = Responsive.horizontalPadding(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 18, hPad, 8),
      child: Row(
        children: [
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
          Expanded(
            child: Text(
              selectedCount == 0
                  ? 'Select items'
                  : '$selectedCount selected',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onSelectAll,
            child: Text(selectAllLabel),
          ),
        ],
      ),
    );
  }
}

class _SelectionActionBar extends StatelessWidget {
  const _SelectionActionBar({
    required this.count,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(18),
      color: isDark ? const Color(0xFF15151C) : Colors.white,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  '$count selected',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: onDelete,
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Remove'),
            ),
          ],
        ),
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
              'Head to Home, paste a YouTube, TikTok, Facebook link, '
              'or direct file URL — your downloads will appear here.',
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
