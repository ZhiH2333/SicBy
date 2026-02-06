import '../domain/track.dart';

abstract class LocalDatabaseService {
  Future<void> upsertTracks(List<Track> tracks);
  Future<List<Track>> getAllTracks();
  Future<List<Track>> getTracksByIds(List<String> ids);
  Future<void> deleteTracksNotIn(Set<String> ids);
  Future<void> clear();
}
