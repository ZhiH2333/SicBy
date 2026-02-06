import '../models/audio_metadata.dart';

abstract class MetadataRepository {
  Future<AudioMetadata?> getByPath(String path);
  Future<void> upsert(AudioMetadata metadata);
  Future<List<AudioMetadata>> getByPaths(List<String> paths);
  Future<void> deleteByPaths(List<String> paths);
}
