import 'package:flutter/foundation.dart';

class CapabilityFlags {
  final bool supportsFolderSelection;
  final bool supportsFileSelection;
  final bool supportsGapless;
  final bool supportsPlaybackSpeed;
  final bool supportsTray;
  final bool supportsBackgroundPlayback;

  const CapabilityFlags({
    required this.supportsFolderSelection,
    required this.supportsFileSelection,
    required this.supportsGapless,
    required this.supportsPlaybackSpeed,
    required this.supportsTray,
    required this.supportsBackgroundPlayback,
  });
}

CapabilityFlags computeCapabilityFlags() {
  final platform = defaultTargetPlatform;
  final isWeb = kIsWeb;

  final isDesktop = !isWeb &&
      (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux);

  return CapabilityFlags(
    supportsFolderSelection: !isWeb,
    supportsFileSelection: isWeb,
    supportsGapless: false,
    supportsPlaybackSpeed: false,
    supportsTray: isDesktop,
    supportsBackgroundPlayback: false,
  );
}
