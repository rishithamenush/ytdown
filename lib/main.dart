import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/downloader/data/services/background_download_service.dart';
import 'features/downloader/data/services/merge_service.dart';
import 'features/downloader/data/services/storage_service.dart';
import 'features/downloader/presentation/pages/splash_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF07070A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  await StorageService.ensureInitialized();
  if (Platform.isAndroid || Platform.isIOS) {
    await MergeService.ensureInitialized();
    await BackgroundDownloadService.ensureInitialized();
  }
  runApp(const ProviderScope(child: VidooryApp()));
}

class VidooryApp extends StatelessWidget {
  const VidooryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: MaterialApp(
        title: 'Vidoory',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const SplashPage(),
        builder: (context, child) {
          // Clamp text scaling so very-large accessibility settings don't
          // break the layout (very-small ones also feel broken to users).
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(
              textScaler: mq.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.3,
              ),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}
