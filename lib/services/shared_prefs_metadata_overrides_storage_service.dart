import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../state/metadata_overrides_models.dart';
import 'metadata_overrides_storage_service.dart';

class SharedPrefsMetadataOverridesStorageService
    implements MetadataOverridesStorageService {
  static const _keyOverrides = 'metadata_overrides';

  @override
  Future<Map<String, TrackMetadataOverride>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyOverrides);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};

    final overrides = <String, TrackMetadataOverride>{};
    decoded.forEach((key, value) {
      if (value is Map) {
        overrides[key.toString()] = TrackMetadataOverride.fromMap(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    });
    return overrides;
  }

  @override
  Future<void> write(Map<String, TrackMetadataOverride> overrides) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = overrides.map((key, value) {
      return MapEntry(key, value.toMap());
    });
    await prefs.setString(_keyOverrides, jsonEncode(payload));
  }

  @override
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOverrides);
  }
}
