import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/metadata_overrides_service.dart';
import 'metadata_overrides_models.dart';
import 'service_providers.dart';

final metadataOverridesProvider =
    StateNotifierProvider<
      MetadataOverridesController,
      Map<String, TrackMetadataOverride>
    >((ref) {
      final storage = ref.read(metadataOverridesServiceProvider);
      return MetadataOverridesController(storage);
    });

class MetadataOverridesController
    extends StateNotifier<Map<String, TrackMetadataOverride>> {
  final MetadataOverridesService _storage;

  MetadataOverridesController(this._storage) : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final overrides = await _storage.read();
    state = overrides;
  }

  TrackMetadataOverride? getOverride(String trackId) => state[trackId];

  Future<void> setOverride(
    String trackId,
    TrackMetadataOverride override,
  ) async {
    final updated = Map<String, TrackMetadataOverride>.from(state);
    updated[trackId] = override;
    state = updated;
    await _storage.write(state);
  }

  Future<void> updateOverride(
    String trackId, {
    String? title,
    String? artist,
    String? album,
    String? artworkPath,
    String? lyrics,
  }) async {
    final current = state[trackId] ?? const TrackMetadataOverride();
    await setOverride(
      trackId,
      current.copyWith(
        title: title,
        artist: artist,
        album: album,
        artworkPath: artworkPath,
        lyrics: lyrics,
      ),
    );
  }

  Future<void> clearArtwork(String trackId) async {
    final current = state[trackId] ?? const TrackMetadataOverride();
    await setOverride(
      trackId,
      TrackMetadataOverride(
        title: current.title,
        artist: current.artist,
        album: current.album,
        artworkPath: null,
        lyrics: current.lyrics,
      ),
    );
  }

  Future<void> clearLyrics(String trackId) async {
    final current = state[trackId] ?? const TrackMetadataOverride();
    await setOverride(
      trackId,
      TrackMetadataOverride(
        title: current.title,
        artist: current.artist,
        album: current.album,
        artworkPath: current.artworkPath,
        lyrics: null,
      ),
    );
  }
}
