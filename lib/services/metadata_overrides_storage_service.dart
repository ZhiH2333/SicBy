import '../state/metadata_overrides_models.dart';

abstract class MetadataOverridesStorageService {
  Future<Map<String, TrackMetadataOverride>> read();
  Future<void> write(Map<String, TrackMetadataOverride> overrides);
  Future<void> reset();
}
