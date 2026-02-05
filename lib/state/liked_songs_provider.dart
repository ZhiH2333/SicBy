import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LikedSongsState {
  final Set<String> trackIds;
  final bool isLoading;
  final String? error;

  const LikedSongsState({
    this.trackIds = const {},
    this.isLoading = false,
    this.error,
  });

  LikedSongsState copyWith({
    Set<String>? trackIds,
    bool? isLoading,
    String? error,
  }) {
    return LikedSongsState(
      trackIds: trackIds ?? this.trackIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final likedSongsProvider =
    StateNotifierProvider<LikedSongsController, LikedSongsState>((ref) {
      return LikedSongsController()..load();
    });

class LikedSongsController extends StateNotifier<LikedSongsState> {
  static const _keyLikedSongs = 'liked_song_ids';

  LikedSongsController() : super(const LikedSongsState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_keyLikedSongs) ?? const [];
      state = state.copyWith(
        trackIds: ids.toSet(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  bool isLiked(String trackId) => state.trackIds.contains(trackId);

  Future<void> toggleLike(String trackId) async {
    final updated = Set<String>.from(state.trackIds);
    if (updated.contains(trackId)) {
      updated.remove(trackId);
    } else {
      updated.add(trackId);
    }
    await _persist(updated);
  }

  Future<void> add(String trackId) async {
    final updated = Set<String>.from(state.trackIds)..add(trackId);
    await _persist(updated);
  }

  Future<void> remove(String trackId) async {
    final updated = Set<String>.from(state.trackIds)..remove(trackId);
    await _persist(updated);
  }

  Future<void> clear() async {
    await _persist(const {});
  }

  Future<void> _persist(Set<String> ids) async {
    state = state.copyWith(trackIds: ids, error: null);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyLikedSongs, ids.toList(growable: false));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
