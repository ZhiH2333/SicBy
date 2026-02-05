import 'package:flutter/material.dart';

/// Simple lyrics modal - UI only
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
                  child: Text(
                    'Lyrics',
                    style: const TextStyle(
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
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.white70,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: SelectableText(
                          lyrics ?? 'No lyrics available for this track.',
                          // Allow accessibility tools to read the content clearly
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

/// Show queue as a bottom sheet with a subtle slide-in using Tween
Future<void> showQueueSheet(BuildContext context, Widget content) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return TweenAnimationBuilder<Offset>(
        tween: Tween(begin: const Offset(0, 0.06), end: Offset.zero),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        builder: (context, offset, child) {
          return Transform.translate(
            offset: Offset(0, offset.dy * MediaQuery.of(context).size.height),
            child: child,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: content,
        ),
      );
    },
  );
}

/// Simple device picker modal - UI only
Future<void> showDevicePicker(BuildContext context, {List<String>? devices}) {
  final deviceList = devices ?? ['This device', 'MacBook Pro', 'Bluetooth Speaker'];
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
        separatorBuilder: (_, __) => const Divider(color: Colors.grey),
        itemBuilder: (context, index) {
          final d = deviceList[index];
          return ListTile(
            title: Text(d, style: const TextStyle(color: Colors.white)),
            trailing: index == 0 ? const Text('Connected', style: TextStyle(color: Colors.green)) : null,
            onTap: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Selected device: $d')));
            },
          );
        },
      );
    },
  );
}

/// Simple share modal - UI only
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
            const Text('Share', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share via...'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share dialog (placeholder)')));
              },
            ),
          ],
        ),
      );
    },
  );
}
