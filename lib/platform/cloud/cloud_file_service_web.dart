import '../../domain/media_locator.dart';
import '../../services/cloud_file_service.dart';

class WebCloudFileService implements CloudFileService {
  @override
  Future<CloudCheckResult> check(MediaLocator locator) async {
    if (locator.kind == MediaLocatorKind.bytes && locator.bytes != null) {
      final sizeMiB = locator.bytes!.length / (1024 * 1024);
      return CloudCheckResult(isCloudOnly: false, sizeMiB: sizeMiB);
    }

    return const CloudCheckResult(
      isCloudOnly: false,
      sizeMiB: 0.0,
      reason: 'unknown',
    );
  }
}

CloudFileService createPlatformCloudFileService() => WebCloudFileService();
