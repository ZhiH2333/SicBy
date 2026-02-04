import '../domain/track.dart';

abstract class LocalDatabaseService {
  Future<void> upsertTracks(List<Track> tracks);
  Future<List<Track>> getAllTracks();
  Future<void> clear();
}
