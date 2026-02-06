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
  Future<List<Track>> getTracksByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final results = <Track>[];
    for (final id in ids) {
      final track = _tracks[id];
      if (track != null) {
        results.add(track);
      }
    }
    return results;
  }

  @override
  Future<void> deleteTracksNotIn(Set<String> ids) async {
    _tracks.removeWhere((key, _) => !ids.contains(key));
  }

  @override
  Future<void> clear() async {
    _tracks.clear();
  }
}
