import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/playback_controller.dart';
import 'package:sicby/state/ui_models.dart';

class CloudDownloadBanner extends ConsumerWidget {
  final Widget child;

  const CloudDownloadBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(playbackControllerProvider);
    final isDownloading =
        playbackState.downloadStatus == DownloadStatus.downloading;

    return Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isDownloading
              ? Container(
                  width: double.infinity,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_download, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Downloading ${playbackState.currentTrack?.title ?? "Track"}...',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: playbackState.downloadProgress,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          ref.read(playbackControllerProvider.notifier).stop();
                        },
                        tooltip: 'Cancel Download',
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(child: child),
      ],
    );
  }
}
