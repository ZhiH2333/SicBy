import 'package:flutter/material.dart';

class CloudConfirmationDialog extends StatelessWidget {
  final String trackTitle;
  final String fileSize;
  final VoidCallback onConfirm;

  const CloudConfirmationDialog({
    super.key,
    required this.trackTitle,
    required this.fileSize,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cloud Content'),
      content: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            const TextSpan(
              text: 'This song appears to be stored in the cloud.\n',
            ),
            const TextSpan(text: 'To play '),
            TextSpan(
              text: trackTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const TextSpan(text: ', please download it.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('No'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: Text('Yes {$fileSize}'),
        ),
      ],
    );
  }
}
