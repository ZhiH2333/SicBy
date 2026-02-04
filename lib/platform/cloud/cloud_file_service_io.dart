import 'dart:io';

import '../../domain/media_locator.dart';
import '../../services/cloud_file_service.dart';

class IoCloudFileService implements CloudFileService {
  @override
  Future<CloudCheckResult> check(MediaLocator locator) async {
    if (locator.kind != MediaLocatorKind.path || locator.path == null) {
      return const CloudCheckResult(isCloudOnly: false, sizeMiB: 0.0);
    }

    final file = File(locator.path!);
    try {
      final stat = await file.stat();
      final sizeMiB = stat.size / (1024 * 1024);
      final isCloudOnly = _isLikelyCloudPlaceholder(locator.path!, stat);
      return CloudCheckResult(
        isCloudOnly: isCloudOnly,
        sizeMiB: sizeMiB,
        reason: isCloudOnly ? 'placeholder' : null,
      );
    } catch (e) {
      return CloudCheckResult(
        isCloudOnly: true,
        sizeMiB: 0.0,
        reason: 'unavailable',
      );
    }
  }

  bool _isLikelyCloudPlaceholder(String path, FileStat stat) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.icloud')) return true;
    if (stat.size == 0 && (lower.contains('icloud') || lower.contains('cloud'))) {
      return true;
    }
    return false;
  }
}

CloudFileService createPlatformCloudFileService() => IoCloudFileService();
