import 'package:shared_preferences/shared_preferences.dart';

import 'search_history_storage_service.dart';

class SharedPrefsSearchHistoryStorageService
    implements SearchHistoryStorageService {
  static const _key = 'search_history';

  @override
  Future<List<String>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  @override
  Future<void> saveHistory(List<String> history) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, history);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
