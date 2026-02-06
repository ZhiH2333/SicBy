abstract class SearchHistoryStorageService {
  Future<List<String>> loadHistory();
  Future<void> saveHistory(List<String> history);
  Future<void> clear();
}
