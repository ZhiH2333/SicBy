import 'package:flutter/material.dart';

/// Now Playing modal helpers: lyrics, queue, device picker, share.

Future<void> showLyricsModal(BuildContext context, {String? lyrics}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        expand: false,
        builder: (context, controller) {
          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[700],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Semantics(
                  header: true,
                  child: const Text(
                    'Lyrics',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.white70,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: SelectableText(
                          lyrics ?? 'No lyrics available for this track.',
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Future<void> showQueueSheet(
  BuildContext context,
  Widget Function(ScrollController) contentBuilder,
) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      // Subtle slide + draggable constraints. Keep UI-only changes.
      return TweenAnimationBuilder<Offset>(
        tween: Tween(begin: const Offset(0, 0.08), end: Offset.zero),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        builder: (context, offset, child) {
          return Transform.translate(
            offset: Offset(0, offset.dy * MediaQuery.of(context).size.height),
            child: child,
          );
        },
        child: Container(
          constraints: BoxConstraints(
            // Avoid full-screen takeover; keep a maximum height similar to Spotify
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            minChildSize: 0.28,
            maxChildSize: 0.92,
            builder: (context, sheetController) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle affordance
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Container(
                        color: Colors.black,
                        child: contentBuilder(sheetController),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}

Future<void> showDevicePicker(BuildContext context, {List<String>? devices}) {
  final deviceList =
      devices ?? ['This device', 'MacBook Pro', 'Bluetooth Speaker'];
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: deviceList.length,
        separatorBuilder: (context, index) => const Divider(color: Colors.grey),
        itemBuilder: (context, index) {
          final d = deviceList[index];
          return ListTile(
            title: Text(d, style: const TextStyle(color: Colors.white)),
            trailing: index == 0
                ? const Text('Connected', style: TextStyle(color: Colors.green))
                : null,
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Selected device: $d')));
            },
          );
        },
      );
    },
  );
}

Future<void> showShareModal(BuildContext context, {String? text}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.black,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Link copied')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share via...'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Share dialog (placeholder)')),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}
