class VirtualFolder {
  final String id;
  final String name;
  final String rootPath;
  final String? parentId;
  final int order;

  const VirtualFolder({
    required this.id,
    required this.name,
    required this.rootPath,
    required this.parentId,
    required this.order,
  });

  VirtualFolder copyWith({
    String? name,
    String? rootPath,
    String? parentId,
    int? order,
  }) {
    return VirtualFolder(
      id: id,
      name: name ?? this.name,
      rootPath: rootPath ?? this.rootPath,
      parentId: parentId ?? this.parentId,
      order: order ?? this.order,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'rootPath': rootPath,
      'parentId': parentId,
      'order': order,
    };
  }

  factory VirtualFolder.fromMap(Map<String, Object?> map) {
    return VirtualFolder(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Folder',
      rootPath: map['rootPath'] as String? ?? '',
      parentId: map['parentId'] as String?,
      order: map['order'] as int? ?? 0,
    );
  }
}

class VirtualLibrarySnapshot {
  final List<VirtualFolder> folders;
  final Map<String, String?> assignments;

  const VirtualLibrarySnapshot({
    required this.folders,
    required this.assignments,
  });

  VirtualLibrarySnapshot copyWith({
    List<VirtualFolder>? folders,
    Map<String, String?>? assignments,
  }) {
    return VirtualLibrarySnapshot(
      folders: folders ?? this.folders,
      assignments: assignments ?? this.assignments,
    );
  }
}

class VirtualLibraryState {
  final List<VirtualFolder> folders;
  final Map<String, String?> assignments;
  final Set<String> expandedFolderIds;
  final Set<String> expandedRootPaths;
  final bool isLoading;
  final String? error;

  const VirtualLibraryState({
    this.folders = const [],
    this.assignments = const {},
    this.expandedFolderIds = const {},
    this.expandedRootPaths = const {},
    this.isLoading = false,
    this.error,
  });

  VirtualLibraryState copyWith({
    List<VirtualFolder>? folders,
    Map<String, String?>? assignments,
    Set<String>? expandedFolderIds,
    Set<String>? expandedRootPaths,
    bool? isLoading,
    String? error,
  }) {
    return VirtualLibraryState(
      folders: folders ?? this.folders,
      assignments: assignments ?? this.assignments,
      expandedFolderIds: expandedFolderIds ?? this.expandedFolderIds,
      expandedRootPaths: expandedRootPaths ?? this.expandedRootPaths,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
