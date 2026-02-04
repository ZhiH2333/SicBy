import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../platform/audio/just_audio_playback_service.dart';
import '../platform/file_system/file_system_service.dart';
import '../services/audio_playback_service.dart';
import '../services/file_system_service.dart';
import '../services/in_memory_local_database_service.dart';
import '../services/local_database_service.dart';

final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return createFileSystemService();
});

final localDatabaseServiceProvider = Provider<LocalDatabaseService>((ref) {
  return InMemoryLocalDatabaseService();
});

final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  return JustAudioPlaybackService();
});
