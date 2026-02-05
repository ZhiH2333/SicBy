import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/virtual_library_storage_service.dart';
import 'service_providers.dart';
import 'virtual_library_models.dart';

final virtualLibraryProvider =
    StateNotifierProvider<VirtualLibraryController, VirtualLibraryState>((ref) {
      final storage = ref.read(virtualLibraryStorageServiceProvider);
      return VirtualLibraryController(storage);
    });

class VirtualLibraryController extends StateNotifier<VirtualLibraryState> {
  final VirtualLibraryStorageService _storage;
  final Random _random = Random();

  VirtualLibraryController(this._storage) : super(const VirtualLibraryState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final snapshot = await _storage.read();
      state = state.copyWith(
        folders: snapshot.folders,
        assignments: snapshot.assignments,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _persist() async {
    await _storage.write(
      VirtualLibrarySnapshot(
        folders: state.folders,
        assignments: state.assignments,
      ),
    );
  }

  void toggleRootExpanded(String rootPath) {
    final expanded = Set<String>.from(state.expandedRootPaths);
    if (!expanded.remove(rootPath)) {
      expanded.add(rootPath);
    }
    state = state.copyWith(expandedRootPaths: expanded);
  }

  void toggleFolderExpanded(String folderId) {
    final expanded = Set<String>.from(state.expandedFolderIds);
    if (!expanded.remove(folderId)) {
      expanded.add(folderId);
    }
    state = state.copyWith(expandedFolderIds: expanded);
  }

  Future<void> createFolder({
    required String name,
    required String rootPath,
    String? parentId,
  }) async {
    final siblings = _siblings(rootPath, parentId);
    final nextOrder = siblings.isEmpty
        ? 0
        : siblings.map((f) => f.order).reduce(max) + 1;
    final folder = VirtualFolder(
      id: _generateId(),
      name: name,
      rootPath: rootPath,
      parentId: parentId,
      order: nextOrder,
    );
    state = state.copyWith(folders: [...state.folders, folder]);
    await _persist();
  }

  Future<void> renameFolder(String folderId, String name) async {
    final updated = state.folders
        .map(
          (folder) =>
              folder.id == folderId ? folder.copyWith(name: name) : folder,
        )
        .toList(growable: false);
    state = state.copyWith(folders: updated);
    await _persist();
  }

  Future<void> deleteFolder(String folderId) async {
    final target = state.folders.firstWhere(
      (folder) => folder.id == folderId,
      orElse: () => const VirtualFolder(
        id: '',
        name: '',
        rootPath: '',
        parentId: null,
        order: 0,
      ),
    );
    if (target.id.isEmpty) return;

    final subtree = _collectSubtree(folderId);
    final updatedFolders = state.folders
        .where((folder) => !subtree.contains(folder.id))
        .toList(growable: false);

    final updatedAssignments = Map<String, String?>.from(state.assignments);
    updatedAssignments.updateAll((trackId, assignedFolder) {
      if (assignedFolder != null && subtree.contains(assignedFolder)) {
        return target.parentId;
      }
      return assignedFolder;
    });

    state = state.copyWith(
      folders: _normalizeOrder(updatedFolders),
      assignments: updatedAssignments,
    );
    await _persist();
  }

  Future<void> moveFolderUp(String folderId) async {
    await _reorderFolder(folderId, -1);
  }

  Future<void> moveFolderDown(String folderId) async {
    await _reorderFolder(folderId, 1);
  }

  Future<void> assignTrack(String trackId, String? folderId) async {
    final updated = Map<String, String?>.from(state.assignments);
    if (folderId == null) {
      updated.remove(trackId);
    } else {
      updated[trackId] = folderId;
    }
    state = state.copyWith(assignments: updated);
    await _persist();
  }

  VirtualFolder? folderById(String folderId) {
    for (final folder in state.folders) {
      if (folder.id == folderId) return folder;
    }
    return null;
  }

  List<VirtualFolder> foldersFor({
    required String rootPath,
    required String? parentId,
  }) {
    final items = state.folders
        .where(
          (folder) =>
              folder.rootPath == rootPath && folder.parentId == parentId,
        )
        .toList(growable: false);
    items.sort((a, b) => a.order.compareTo(b.order));
    return items;
  }

  Set<String> _collectSubtree(String folderId) {
    final out = <String>{};
    final queue = <String>[folderId];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      out.add(current);
      final children = state.folders
          .where((folder) => folder.parentId == current)
          .map((folder) => folder.id);
      queue.addAll(children);
    }
    return out;
  }

  List<VirtualFolder> _siblings(String rootPath, String? parentId) {
    return state.folders
        .where(
          (folder) =>
              folder.rootPath == rootPath && folder.parentId == parentId,
        )
        .toList(growable: false);
  }

  Future<void> _reorderFolder(String folderId, int delta) async {
    final target = state.folders.firstWhere(
      (folder) => folder.id == folderId,
      orElse: () => const VirtualFolder(
        id: '',
        name: '',
        rootPath: '',
        parentId: null,
        order: 0,
      ),
    );
    if (target.id.isEmpty) return;

    final siblings = _siblings(target.rootPath, target.parentId);
    siblings.sort((a, b) => a.order.compareTo(b.order));
    final index = siblings.indexWhere((folder) => folder.id == folderId);
    final nextIndex = index + delta;
    if (index == -1 || nextIndex < 0 || nextIndex >= siblings.length) return;

    final reordered = List<VirtualFolder>.from(siblings);
    final moved = reordered.removeAt(index);
    reordered.insert(nextIndex, moved);

    final updated = state.folders
        .map((folder) {
          if (folder.rootPath != target.rootPath ||
              folder.parentId != target.parentId) {
            return folder;
          }
          final newIndex = reordered.indexWhere((item) => item.id == folder.id);
          return folder.copyWith(order: newIndex);
        })
        .toList(growable: false);

    state = state.copyWith(folders: updated);
    await _persist();
  }

  List<VirtualFolder> _normalizeOrder(List<VirtualFolder> folders) {
    final grouped = <String, List<VirtualFolder>>{};
    for (final folder in folders) {
      final key = '${folder.rootPath}|${folder.parentId ?? 'root'}';
      grouped.putIfAbsent(key, () => []).add(folder);
    }

    final normalized = <VirtualFolder>[];
    for (final group in grouped.values) {
      group.sort((a, b) => a.order.compareTo(b.order));
      for (var i = 0; i < group.length; i++) {
        normalized.add(group[i].copyWith(order: i));
      }
    }
    return normalized;
  }

  String _generateId() {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final salt = _random.nextInt(100000);
    return 'vf_${stamp}_$salt';
  }
}
