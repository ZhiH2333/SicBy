import '../domain/track.dart';
import 'local_database_service.dart';

class InMemoryLocalDatabaseService implements LocalDatabaseService {
  final Map<String, Track> _tracks = {};

  @override
  Future<void> upsertTracks(List<Track> tracks) async {
    for (final track in tracks) {
      _tracks[track.id] = track;
    }
  }

  @override
  Future<List<Track>> getAllTracks() async {
    return _tracks.values.toList(growable: false);
  }

  @override
  Future<void> clear() async {
    _tracks.clear();
  }
}
