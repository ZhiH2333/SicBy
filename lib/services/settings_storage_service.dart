import '../state/settings_models.dart';

abstract class SettingsStorageService {
  Future<AppSettings> read();
  Future<void> write(AppSettings settings);
  Future<void> reset();
}
