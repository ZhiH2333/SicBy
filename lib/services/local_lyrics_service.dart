import 'dart:io';

import '../domain/media_locator.dart';

class LyricLine {
  final Duration timestamp;
  final String text;

  const LyricLine({required this.timestamp, required this.text});
}

class LocalLyricsService {
  Future<List<LyricLine>> load(MediaLocator locator) async {
    if (locator.kind != MediaLocatorKind.path || locator.path == null) {
      return const [];
    }

    final path = locator.path!;
    final base = path.replaceAll(RegExp(r'\.[^.]+$'), '');
    final candidates = [File('$base.lrc'), File('$base.txt')];

    for (final file in candidates) {
      if (await file.exists()) {
        final content = await file.readAsString();
        final lines = parseText(content);
        if (lines.isNotEmpty) return lines;
      }
    }

    return const [];
  }

  List<LyricLine> parseText(String content) {
    final result = <LyricLine>[];
    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final match = RegExp(
        r'^\[(\d+):(\d+)(?:\.(\d+))?\](.*)$',
      ).firstMatch(line);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final millis = int.tryParse(match.group(3) ?? '') ?? 0;
        final text = (match.group(4) ?? '').trim();
        result.add(
          LyricLine(
            timestamp: Duration(
              minutes: minutes,
              seconds: seconds,
              milliseconds: millis * 10,
            ),
            text: text,
          ),
        );
      } else {
        result.add(LyricLine(timestamp: Duration.zero, text: line));
      }
    }
    return result;
  }
}
