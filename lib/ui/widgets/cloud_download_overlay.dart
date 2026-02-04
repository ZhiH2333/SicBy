import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/playback_controller.dart';

import 'package:sicby/state/ui_models.dart';

class CloudDownloadOverlay extends ConsumerWidget {
  final Widget child;

  const CloudDownloadOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(playbackControllerProvider);

    return Stack(
      children: [
        child,
        if (playbackState.downloadStatus == DownloadStatus.downloading)
          Container(
            color: Colors.black.withAlpha(150),
            child: Center(
              child: Card(
                color: Theme.of(context).cardColor,
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Preparing Track...',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: playbackState.downloadProgress,
                          backgroundColor: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(playbackState.downloadProgress * 100).toInt()}%',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
