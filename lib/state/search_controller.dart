import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/search_history_storage_service.dart';
import 'service_providers.dart';

class SearchState {
  final String query;
  final List<String> history;

  const SearchState({this.query = '', this.history = const []});

  SearchState copyWith({String? query, List<String>? history}) {
    return SearchState(
      query: query ?? this.query,
      history: history ?? this.history,
    );
  }
}

final searchControllerProvider =
    StateNotifierProvider<SearchController, SearchState>((ref) {
      final storage = ref.read(searchHistoryStorageProvider);
      final controller = SearchController(storage);
      controller.load();
      return controller;
    });

class SearchController extends StateNotifier<SearchState> {
  final SearchHistoryStorageService _storage;
  static const int _maxEntries = 12;

  SearchController(this._storage) : super(const SearchState());

  Future<void> load() async {
    final history = await _storage.loadHistory();
    state = state.copyWith(history: history);
  }

  void updateQuery(String value) {
    state = state.copyWith(query: value);
  }

  Future<void> addHistory(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    final next = [
      query,
      ...state.history.where((item) => item != query),
    ];
    final trimmed = next.take(_maxEntries).toList(growable: false);
    state = state.copyWith(history: trimmed);
    await _storage.saveHistory(trimmed);
  }

  Future<void> removeHistory(String value) async {
    final trimmed = state.history.where((item) => item != value).toList();
    state = state.copyWith(history: trimmed);
    await _storage.saveHistory(trimmed);
  }

  Future<void> clearHistory() async {
    state = state.copyWith(history: const []);
    await _storage.clear();
  }
}
