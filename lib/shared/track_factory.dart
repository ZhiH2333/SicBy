import '../domain/track.dart';
import '../services/file_system_service.dart';

class TrackFactory {
  Track createFromMediaFile(MediaFile file) {
    final title = _titleFromName(file.name);
    final id = _deterministicId(file);

    return Track(
      id: id,
      title: title,
      artistName: 'Unknown Artist',
      duration: Duration.zero,
      locator: file.locator,
      albumName: null,
      lastModified: file.lastModified,
      fileSizeBytes: file.sizeBytes,
    );
  }

  String _titleFromName(String name) {
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex <= 0) return name;
    return name.substring(0, dotIndex);
  }

  String _deterministicId(MediaFile file) {
    final locator = file.locator;
    if (locator.path != null && locator.path!.isNotEmpty) {
      return locator.path!;
    }
    if (locator.uri != null && locator.uri!.isNotEmpty) {
      return locator.uri!;
    }

    final size = file.sizeBytes ?? locator.bytes?.length ?? 0;
    return '${file.name}|$size';
  }
}
