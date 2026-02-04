import '../domain/media_locator.dart';

class CloudCheckResult {
  final bool isCloudOnly;
  final double sizeMiB;
  final String? reason;

  const CloudCheckResult({
    required this.isCloudOnly,
    required this.sizeMiB,
    this.reason,
  });
}

abstract class CloudFileService {
  Future<CloudCheckResult> check(MediaLocator locator);
}
