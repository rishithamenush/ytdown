import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'screens/home_screen.dart';
import 'services/background_download_service.dart';
import 'services/merge_service.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

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
  runApp(const YtDownApp());
}

class YtDownApp extends StatelessWidget {
  const YtDownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: MaterialApp(
        title: 'YT Down',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: const HomeScreen(),
      ),
    );
  }
}
