import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  // Returns version + build number (e.g., 1.0.0+1)
  return "${packageInfo.version}+${packageInfo.buildNumber}";
});
