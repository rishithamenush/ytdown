import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/responsive.dart';
import '../../domain/entities/download_task.dart';
import '../providers/home_notifier.dart';
import '../widgets/ambient_background.dart';
import '../widgets/download_task_tile.dart';
import '../widgets/error_banner.dart';
import '../widgets/gradient_button.dart';
import '../widgets/hero_section.dart';
import '../widgets/quality_tile.dart';
import '../widgets/search_field.dart';
import '../widgets/section_header.dart';
import '../widgets/top_bar.dart';
import '../widgets/video_preview_card.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Rebuild on every keystroke so the search field's X button appears /
    // disappears as the user types.
    _urlController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    FocusScope.of(context).unfocus();
    await ref.read(homeNotifierProvider.notifier).fetchVideo(
          _urlController.text,
        );
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    _urlController.text = text;
    _urlController.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
  }

  void _clearSearch() {
    _urlController.clear();
    ref.read(homeNotifierProvider.notifier).clearSearch();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(homeNotifierProvider);
    final notifier = ref.read(homeNotifierProvider.notifier);
    final hPad = Responsive.horizontalPadding(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(child: AmbientBackground()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: TopBar(activeCount: state.activeTaskCount),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
                  sliver: SliverList.list(
                    children: [
                      const HeroSection(),
                      const SizedBox(height: 20),
                      SearchField(
                        controller: _urlController,
                        loading: state.loading,
                        onSubmit: _fetch,
                        onPaste: _paste,
                        onClear: _clearSearch,
                      ),
                      const SizedBox(height: 14),
                      GradientButton(
                        onPressed: state.loading ? null : _fetch,
                        loading: state.loading,
                        label: state.loading ? 'Fetching video…' : 'Get video',
                        icon: Icons.search_rounded,
                      ),
                      if (state.error != null) ...[
                        const SizedBox(height: 16),
                        ErrorBanner(message: state.error!),
                      ],
                      if (state.tasks.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        SectionHeader(
                          icon: Icons.downloading_rounded,
                          title: 'Downloads',
                          trailingAction: state.hasFinishedTasks
                              ? TextButton(
                                  onPressed: notifier.clearFinishedTasks,
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
                              onDismiss: () => notifier.dismissTask(t.id),
                            ),
                          ),
                        ),
                      ],
                      if (state.video != null) ...[
                        const SizedBox(height: 28),
                        VideoPreviewCard(video: state.video!),
                        const SizedBox(height: 24),
                        const SectionHeader(
                          icon: Icons.high_quality_rounded,
                          title: 'Choose quality',
                          subtitle:
                              'Tap multiple to download in parallel. HD options merge video + audio.',
                        ),
                        const SizedBox(height: 12),
                        ...state.streams.map((stream) {
                          final task = notifier.taskForStream(stream);
                          final downloading = task?.isActive ?? false;
                          final completed =
                              task?.status == DownloadTaskStatus.completed
                                  ? task
                                  : null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: QualityTile(
                              stream: stream,
                              activeTask: downloading ? task : null,
                              completedTask: completed,
                              onTap: downloading
                                  ? null
                                  : () => notifier.startDownload(stream),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Text(
                          'Files save to Movies/Vidoory (video) or Download/Vidoory (audio).',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
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
    );
  }
}
