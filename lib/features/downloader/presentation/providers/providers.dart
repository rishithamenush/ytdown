import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/direct_link_remote_datasource.dart';
import '../../data/datasources/facebook_remote_datasource.dart';
import '../../data/datasources/tiktok_remote_datasource.dart';
import '../../data/datasources/youtube_remote_datasource.dart';
import '../../data/repositories/composite_video_repository.dart';
import '../../data/repositories/direct_link_video_repository_impl.dart';
import '../../data/repositories/download_notification_repository_impl.dart';
import '../../data/repositories/facebook_video_repository_impl.dart';
import '../../data/repositories/tiktok_video_repository_impl.dart';
import '../../data/repositories/video_repository_impl.dart';
import '../../data/services/direct_link_cookie_store.dart';
import '../../data/services/download_history_service.dart';
import '../../data/services/file_preview_service.dart';
import '../../domain/repositories/download_notification_repository.dart';
import '../../domain/repositories/video_repository.dart';
import '../../domain/usecases/download_stream_use_case.dart';
import '../../domain/usecases/fetch_video_info.dart';

final youtubeRemoteDataSourceProvider = Provider<YoutubeRemoteDataSource>((ref) {
  final ds = YoutubeRemoteDataSource();
  ref.onDispose(ds.dispose);
  return ds;
});

final tiktokRemoteDataSourceProvider = Provider<TiktokRemoteDataSource>((ref) {
  return TiktokRemoteDataSource();
});

final facebookRemoteDataSourceProvider =
    Provider<FacebookRemoteDataSource>((ref) {
  return FacebookRemoteDataSource();
});

final directLinkRemoteDataSourceProvider =
    Provider<DirectLinkRemoteDataSource>((ref) {
  return DirectLinkRemoteDataSource();
});

final directLinkCookieStoreProvider = Provider<DirectLinkCookieStore>((ref) {
  return DirectLinkCookieStore();
});

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

final facebookVideoRepositoryProvider = Provider<VideoRepository>((ref) {
  final remote = ref.watch(facebookRemoteDataSourceProvider);
  return FacebookVideoRepositoryImpl(remote);
});

final directLinkVideoRepositoryProvider = Provider<VideoRepository>((ref) {
  final remote = ref.watch(directLinkRemoteDataSourceProvider);
  final cookies = ref.watch(directLinkCookieStoreProvider);
  return DirectLinkVideoRepositoryImpl(remote, cookies);
});

final videoRepositoryProvider = Provider<VideoRepository>((ref) {
  final youtube = ref.watch(youtubeVideoRepositoryProvider);
  final tiktok = ref.watch(tiktokVideoRepositoryProvider);
  final facebook = ref.watch(facebookVideoRepositoryProvider);
  final directLink = ref.watch(directLinkVideoRepositoryProvider);
  final repo = CompositeVideoRepository(
    youtube: youtube,
    tiktok: tiktok,
    facebook: facebook,
    directLink: directLink,
  );
  ref.onDispose(repo.dispose);
  return repo;
});

final downloadNotificationRepositoryProvider =
    Provider<DownloadNotificationRepository>((ref) {
  return const DownloadNotificationRepositoryImpl();
});

final downloadHistoryServiceProvider = Provider<DownloadHistoryService>((ref) {
  return DownloadHistoryService();
});

final filePreviewServiceProvider = Provider<FilePreviewService>((ref) {
  return const FilePreviewService();
});

final fetchVideoInfoProvider = Provider<FetchVideoInfo>((ref) {
  return FetchVideoInfo(ref.watch(videoRepositoryProvider));
});

final downloadStreamUseCaseProvider = Provider<DownloadStreamUseCase>((ref) {
  return DownloadStreamUseCase(ref.watch(videoRepositoryProvider));
});
