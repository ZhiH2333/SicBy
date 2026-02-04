import 'dart:math';

enum LoopMode { off, all, one }

class QueueState {
  final List<String> order;
  final List<String> originalOrder;
  final bool shuffleEnabled;
  final LoopMode loopMode;
  final int currentIndex;

  const QueueState({
    required this.order,
    required this.originalOrder,
    required this.shuffleEnabled,
    required this.loopMode,
    required this.currentIndex,
  });

  String? get currentTrackId {
    if (currentIndex < 0 || currentIndex >= order.length) return null;
    return order[currentIndex];
  }

  QueueState copyWith({
    List<String>? order,
    List<String>? originalOrder,
    bool? shuffleEnabled,
    LoopMode? loopMode,
    int? currentIndex,
  }) {
    return QueueState(
      order: order ?? this.order,
      originalOrder: originalOrder ?? this.originalOrder,
      shuffleEnabled: shuffleEnabled ?? this.shuffleEnabled,
      loopMode: loopMode ?? this.loopMode,
      currentIndex: currentIndex ?? this.currentIndex,
    );
  }
}

QueueState createQueue(List<String> trackIds) {
  return QueueState(
    order: List<String>.from(trackIds),
    originalOrder: List<String>.from(trackIds),
    shuffleEnabled: false,
    loopMode: LoopMode.off,
    currentIndex: trackIds.isEmpty ? -1 : 0,
  );
}

QueueState addToQueue(QueueState state, String trackId) {
  final updated = List<String>.from(state.order)..add(trackId);
  final original = List<String>.from(state.originalOrder)..add(trackId);
  return state.copyWith(order: updated, originalOrder: original);
}

QueueState removeFromQueue(QueueState state, String trackId) {
  final updated = List<String>.from(state.order)..remove(trackId);
  final original = List<String>.from(state.originalOrder)..remove(trackId);
  var index = state.currentIndex;
  if (index >= updated.length) index = updated.length - 1;
  return state.copyWith(order: updated, originalOrder: original, currentIndex: index);
}

QueueState reorderQueue(QueueState state, int from, int to) {
  if (from < 0 || from >= state.order.length) return state;
  if (to < 0 || to >= state.order.length) return state;
  final updated = List<String>.from(state.order);
  final item = updated.removeAt(from);
  updated.insert(to, item);
  return state.copyWith(order: updated);
}

QueueState enableShuffle(QueueState state, {Random? random}) {
  if (state.shuffleEnabled) return state;
  final rng = random ?? Random();
  final updated = List<String>.from(state.order);
  updated.shuffle(rng);
  final currentId = state.currentTrackId;
  final index = currentId == null ? -1 : updated.indexOf(currentId);
  return state.copyWith(
    order: updated,
    originalOrder: List<String>.from(state.order),
    shuffleEnabled: true,
    currentIndex: index,
  );
}

QueueState disableShuffle(QueueState state) {
  if (!state.shuffleEnabled) return state;
  final currentId = state.currentTrackId;
  final updated = List<String>.from(state.originalOrder);
  final index = currentId == null ? -1 : updated.indexOf(currentId);
  return state.copyWith(
    order: updated,
    shuffleEnabled: false,
    currentIndex: index,
  );
}

int? nextIndex(QueueState state) {
  if (state.order.isEmpty) return null;
  if (state.loopMode == LoopMode.one) return state.currentIndex;
  final next = state.currentIndex + 1;
  if (next < state.order.length) return next;
  if (state.loopMode == LoopMode.all) return 0;
  return null;
}

int? previousIndex(QueueState state) {
  if (state.order.isEmpty) return null;
  if (state.loopMode == LoopMode.one) return state.currentIndex;
  final prev = state.currentIndex - 1;
  if (prev >= 0) return prev;
  if (state.loopMode == LoopMode.all) return state.order.length - 1;
  return null;
}

class SleepTimerConfig {
  final Duration duration;
  final bool stopAtEndOfTrack;

  const SleepTimerConfig({
    required this.duration,
    required this.stopAtEndOfTrack,
  });
}

DateTime scheduleSleepTimer(DateTime now, SleepTimerConfig config) {
  return now.add(config.duration);
}

bool isSleepTimerExpired(DateTime now, DateTime scheduledEnd) {
  return now.isAfter(scheduledEnd) || now.isAtSameMomentAs(scheduledEnd);
}
