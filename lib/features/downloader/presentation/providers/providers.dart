import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/tiktok_remote_datasource.dart';
import '../../data/datasources/youtube_remote_datasource.dart';
import '../../data/repositories/composite_video_repository.dart';
import '../../data/repositories/download_notification_repository_impl.dart';
import '../../data/repositories/tiktok_video_repository_impl.dart';
import '../../data/repositories/video_repository_impl.dart';
import '../../domain/repositories/download_notification_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../../domain/usecases/download_stream_use_case.dart';
import '../../domain/usecases/fetch_video_info.dart';

/// Riverpod DI graph for the downloader feature.
///
/// All construction lives here so swapping a repository implementation later
/// (e.g. mocking for tests) only requires overriding one provider — every
/// downstream consumer keeps its imports unchanged.

// ── data layer ──────────────────────────────────────────────────────────────

final youtubeRemoteDataSourceProvider = Provider<YoutubeRemoteDataSource>((ref) {
  final ds = YoutubeRemoteDataSource();
  ref.onDispose(ds.dispose);
  return ds;
});

final tiktokRemoteDataSourceProvider = Provider<TiktokRemoteDataSource>((ref) {
  return TiktokRemoteDataSource();
});

// ── domain → repository implementations ─────────────────────────────────────

final youtubeVideoRepositoryProvider = Provider<VideoRepository>((ref) {
  final remote = ref.watch(youtubeRemoteDataSourceProvider);
  final repo = VideoRepositoryImpl(remote);
  ref.onDispose(repo.dispose);
  return repo;
});

final tiktokVideoRepositoryProvider = Provider<VideoRepository>((ref) {
  final remote = ref.watch(tiktokRemoteDataSourceProvider);
  return TiktokVideoRepositoryImpl(remote);
});

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  final youtube = ref.watch(youtubeVideoRepositoryProvider);
  final tiktok = ref.watch(tiktokVideoRepositoryProvider);
  final repo = CompositeVideoRepository(youtube: youtube, tiktok: tiktok);
  ref.onDispose(repo.dispose);
  return repo;
});

final downloadNotificationRepositoryProvider =
    Provider<DownloadNotificationRepository>((ref) {
  return const DownloadNotificationRepositoryImpl();
});

// ── use cases ───────────────────────────────────────────────────────────────

final fetchVideoInfoProvider = Provider<FetchVideoInfo>((ref) {
  return FetchVideoInfo(ref.watch(videoRepositoryProvider));
});

final downloadStreamUseCaseProvider = Provider<DownloadStreamUseCase>((ref) {
  return DownloadStreamUseCase(ref.watch(videoRepositoryProvider));
});
