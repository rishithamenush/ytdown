import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App version from [pubspec.yaml] (`version` + `build-number`), injected at build time.
final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

/// Matches [pubspec.yaml] `version:` (e.g. `1.0.0+1`).
String formatAppVersion(PackageInfo info) {
  final build = info.buildNumber.trim();
  if (build.isEmpty) return info.version;
  return '${info.version}+$build';
}
