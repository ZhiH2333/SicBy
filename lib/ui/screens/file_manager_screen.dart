import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/local_library_provider.dart';
import 'package:sicby/state/liked_songs_provider.dart';
import 'package:sicby/state/playback_controller.dart';
import 'package:sicby/state/ui_models.dart';
import 'package:sicby/state/virtual_library_controller.dart';
import 'package:sicby/state/virtual_library_models.dart';

class FileManagerScreen extends ConsumerWidget {
  const FileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(localLibraryProvider);
    final libraryController = ref.read(localLibraryProvider.notifier);
    final playbackController = ref.read(playbackControllerProvider.notifier);
    final likeController = ref.read(likeControllerProvider.notifier);
    final likedState = ref.watch(likeControllerProvider);
    final virtualState = ref.watch(virtualLibraryProvider);
    final virtualController = ref.read(virtualLibraryProvider.notifier);
    final folderById = {
      for (final folder in virtualState.folders) folder.id: folder,
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => libraryController.scanFromSettings(),
            tooltip: 'Rescan',
          ),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => libraryController.pickAndAddFolder(),
            tooltip: 'Add Folder',
          ),
        ],
      ),
      body: ListView(
        children: [
          _Section(
            title: 'Library Sources',
            children: [
              if (libraryState.scannedPaths.isEmpty)
                const ListTile(
                  title: Text('No folders added'),
                  subtitle: Text('Add a folder to build your library'),
                ),
              ...libraryState.scannedPaths.map(
                (path) => ListTile(
                  title: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => libraryController.removeLibraryPath(path),
                  ),
                ),
              ),
            ],
          ),
          _Section(
            title: 'Virtual Folders',
            children: _buildFolderTree(
              context: context,
              rootPaths: libraryState.scannedPaths,
              libraryState: libraryState,
              playbackController: playbackController,
              likedState: likedState,
              likeController: likeController,
              virtualState: virtualState,
              virtualController: virtualController,
              folderById: folderById,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          ...children,
        ],
      ),
    );
  }
}

List<Widget> _buildFolderTree({
  required BuildContext context,
  required List<String> rootPaths,
  required LocalLibraryState libraryState,
  required PlaybackController playbackController,
  required LikedSongsState likedState,
  required LikedSongsController likeController,
  required VirtualLibraryState virtualState,
  required VirtualLibraryController virtualController,
  required Map<String, VirtualFolder> folderById,
}) {
  if (libraryState.isLoading) {
    return const [ListTile(title: Text('Scanning library...'))];
  }

  if (rootPaths.isEmpty) {
    return const [
      ListTile(title: Text('Add a library folder to begin organizing')),
    ];
  }

  final rootForTrack = <String, String?>{};
  for (final track in libraryState.tracks) {
    final path = track.filePath ?? '';
    rootForTrack[track.id] = _rootPathForTrack(path, rootPaths);
  }

  final tracksByFolder = <String, List<UiTrack>>{};
  final rootTracks = <String, List<UiTrack>>{};

  for (final track in libraryState.tracks) {
    final rootPath = rootForTrack[track.id];
    if (rootPath == null) {
      continue;
    }
    final assignedFolderId = virtualState.assignments[track.id];
    final folder = assignedFolderId != null
        ? folderById[assignedFolderId]
        : null;
    if (folder != null && folder.rootPath == rootPath) {
      tracksByFolder.putIfAbsent(folder.id, () => []).add(track);
    } else {
      rootTracks.putIfAbsent(rootPath, () => []).add(track);
    }
  }

  for (final list in tracksByFolder.values) {
    list.sort((a, b) => a.title.compareTo(b.title));
  }
  for (final list in rootTracks.values) {
    list.sort((a, b) => a.title.compareTo(b.title));
  }

  final items = <Widget>[];
  for (final rootPath in rootPaths) {
    final expanded = virtualState.expandedRootPaths.contains(rootPath);
    items.add(
      _RootRow(
        rootPath: rootPath,
        isExpanded: expanded,
        onToggle: () => virtualController.toggleRootExpanded(rootPath),
        onCreateFolder: () => _showCreateFolderDialog(
          context,
          virtualController: virtualController,
          rootPath: rootPath,
          parentId: null,
        ),
      ),
    );

    if (!expanded) {
      continue;
    }

    final rootFolderNodes = _buildFolderNodes(
      context: context,
      rootPath: rootPath,
      parentId: null,
      depth: 1,
      playbackController: playbackController,
      likedState: likedState,
      likeController: likeController,
      virtualState: virtualState,
      virtualController: virtualController,
      folderById: folderById,
      tracksByFolder: tracksByFolder,
    );
    items.addAll(rootFolderNodes);

    final unassignedTracks = rootTracks[rootPath] ?? [];
    if (unassignedTracks.isEmpty && rootFolderNodes.isEmpty) {
      items.add(
        const Padding(
          padding: EdgeInsets.only(left: 24, bottom: 8),
          child: Text(
            'No folders or tracks found',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    for (final track in unassignedTracks) {
      items.add(
        _TrackRow(
          track: track,
          indent: 2,
          isLiked: likedState.trackIds.contains(track.id),
          onTap: () =>
              playbackController.play(track, queue: libraryState.tracks),
          onLongPress: () => _showTrackActions(
            context,
            track: track,
            isLiked: likedState.trackIds.contains(track.id),
            likeController: likeController,
            playbackController: playbackController,
            onMove: () => _showMoveTrackDialog(
              context,
              track: track,
              rootPath: rootPath,
              folderById: folderById,
              virtualState: virtualState,
              virtualController: virtualController,
            ),
          ),
        ),
      );
    }
  }

  return items;
}

List<Widget> _buildFolderNodes({
  required BuildContext context,
  required String rootPath,
  required String? parentId,
  required int depth,
  required PlaybackController playbackController,
  required LikedSongsState likedState,
  required LikedSongsController likeController,
  required VirtualLibraryState virtualState,
  required VirtualLibraryController virtualController,
  required Map<String, VirtualFolder> folderById,
  required Map<String, List<UiTrack>> tracksByFolder,
}) {
  final folders = virtualController.foldersFor(
    rootPath: rootPath,
    parentId: parentId,
  );
  final widgets = <Widget>[];
  for (final folder in folders) {
    final expanded = virtualState.expandedFolderIds.contains(folder.id);
    final siblings = virtualController.foldersFor(
      rootPath: rootPath,
      parentId: parentId,
    );
    final index = siblings.indexWhere((item) => item.id == folder.id);
    widgets.add(
      _FolderRow(
        folder: folder,
        depth: depth,
        isExpanded: expanded,
        canMoveUp: index > 0,
        canMoveDown: index != -1 && index < siblings.length - 1,
        onToggle: () => virtualController.toggleFolderExpanded(folder.id),
        onCreateSubfolder: () => _showCreateFolderDialog(
          context,
          virtualController: virtualController,
          rootPath: rootPath,
          parentId: folder.id,
        ),
        onRename: () => _showRenameFolderDialog(
          context,
          folder: folder,
          virtualController: virtualController,
        ),
        onDelete: () => _confirmDeleteFolder(
          context,
          folder: folder,
          virtualController: virtualController,
        ),
        onMoveUp: () => virtualController.moveFolderUp(folder.id),
        onMoveDown: () => virtualController.moveFolderDown(folder.id),
      ),
    );

    if (expanded) {
      widgets.addAll(
        _buildFolderNodes(
          context: context,
          rootPath: rootPath,
          parentId: folder.id,
          depth: depth + 1,
          playbackController: playbackController,
          likedState: likedState,
          likeController: likeController,
          virtualState: virtualState,
          virtualController: virtualController,
          folderById: folderById,
          tracksByFolder: tracksByFolder,
        ),
      );

      final folderTracks = tracksByFolder[folder.id] ?? [];
      for (final track in folderTracks) {
        widgets.add(
          _TrackRow(
            track: track,
            indent: depth + 1,
            isLiked: likedState.trackIds.contains(track.id),
            onTap: () => playbackController.play(track, queue: folderTracks),
            onLongPress: () => _showTrackActions(
              context,
              track: track,
              isLiked: likedState.trackIds.contains(track.id),
              likeController: likeController,
              playbackController: playbackController,
              onMove: () => _showMoveTrackDialog(
                context,
                track: track,
                rootPath: rootPath,
                folderById: folderById,
                virtualState: virtualState,
                virtualController: virtualController,
              ),
            ),
          ),
        );
      }
    }
  }
  return widgets;
}

String? _rootPathForTrack(String path, List<String> roots) {
  if (path.isEmpty) return null;
  String? bestMatch;
  for (final root in roots) {
    if (path.startsWith(root)) {
      if (bestMatch == null || root.length > bestMatch.length) {
        bestMatch = root;
      }
    }
  }
  return bestMatch;
}

Future<void> _showCreateFolderDialog(
  BuildContext context, {
  required VirtualLibraryController virtualController,
  required String rootPath,
  required String? parentId,
}) async {
  final controller = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      );
    },
  );
  if (name == null || name.isEmpty) return;
  await virtualController.createFolder(
    name: name,
    rootPath: rootPath,
    parentId: parentId,
  );
}

Future<void> _showRenameFolderDialog(
  BuildContext context, {
  required VirtualFolder folder,
  required VirtualLibraryController virtualController,
}) async {
  final controller = TextEditingController(text: folder.name);
  final name = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Folder name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      );
    },
  );
  if (name == null || name.isEmpty || name == folder.name) return;
  await virtualController.renameFolder(folder.id, name);
}

Future<void> _confirmDeleteFolder(
  BuildContext context, {
  required VirtualFolder folder,
  required VirtualLibraryController virtualController,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Delete folder'),
        content: Text(
          "Delete folder '${folder.name}'? This will not delete files from your device.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      );
    },
  );
  if (confirmed != true) return;
  await virtualController.deleteFolder(folder.id);
}

Future<void> _showTrackActions(
  BuildContext context, {
  required UiTrack track,
  required bool isLiked,
  required LikedSongsController likeController,
  required PlaybackController playbackController,
  required VoidCallback onMove,
}) async {
  await showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Add to queue'),
              onTap: () {
                playbackController.addToQueue(track);
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Move to folder'),
              onTap: () {
                Navigator.of(context).pop();
                onMove();
              },
            ),
            ListTile(
              leading: Icon(isLiked ? Icons.favorite : Icons.favorite_border),
              title: Text(isLiked ? 'Remove from liked' : 'Add to liked'),
              onTap: () {
                likeController.toggleLike(track.id);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _showMoveTrackDialog(
  BuildContext context, {
  required UiTrack track,
  required String rootPath,
  required Map<String, VirtualFolder> folderById,
  required VirtualLibraryState virtualState,
  required VirtualLibraryController virtualController,
}) async {
  final currentFolderId = virtualState.assignments[track.id];
  final folders = virtualState.folders
      .where((folder) => folder.rootPath == rootPath)
      .toList(growable: false);
  folders.sort((a, b) => a.order.compareTo(b.order));
  final folderByParent = <String?, List<VirtualFolder>>{};
  for (final folder in folders) {
    folderByParent.putIfAbsent(folder.parentId, () => []).add(folder);
  }
  for (final group in folderByParent.values) {
    group.sort((a, b) => a.order.compareTo(b.order));
  }

  await showModalBottomSheet(
    context: context,
    builder: (context) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.layers_clear),
              title: const Text('No folder (root)'),
              trailing: currentFolderId == null
                  ? const Icon(Icons.check)
                  : null,
              onTap: () async {
                await virtualController.assignTrack(track.id, null);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
            ..._buildFolderChoices(
              folderByParent: folderByParent,
              parentId: null,
              depth: 1,
              currentFolderId: currentFolderId,
              onSelect: (folderId) async {
                await virtualController.assignTrack(track.id, folderId);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    },
  );
}

List<Widget> _buildFolderChoices({
  required Map<String?, List<VirtualFolder>> folderByParent,
  required String? parentId,
  required int depth,
  required String? currentFolderId,
  required Future<void> Function(String) onSelect,
}) {
  final folders = folderByParent[parentId] ?? [];
  final widgets = <Widget>[];
  for (final folder in folders) {
    widgets.add(
      _FolderChoiceRow(
        folder: folder,
        depth: depth,
        isSelected: folder.id == currentFolderId,
        onTap: () => onSelect(folder.id),
      ),
    );
    widgets.addAll(
      _buildFolderChoices(
        folderByParent: folderByParent,
        parentId: folder.id,
        depth: depth + 1,
        currentFolderId: currentFolderId,
        onSelect: onSelect,
      ),
    );
  }
  return widgets;
}

class _RootRow extends StatelessWidget {
  const _RootRow({
    required this.rootPath,
    required this.isExpanded,
    required this.onToggle,
    required this.onCreateFolder,
  });

  final String rootPath;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onCreateFolder;

  @override
  Widget build(BuildContext context) {
    final name = _basename(rootPath);
    return ListTile(
      leading: Icon(isExpanded ? Icons.folder_open : Icons.folder),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(rootPath, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: onCreateFolder,
            tooltip: 'New folder',
          ),
          IconButton(
            icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
            onPressed: onToggle,
            tooltip: isExpanded ? 'Collapse' : 'Expand',
          ),
        ],
      ),
      onTap: onToggle,
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.folder,
    required this.depth,
    required this.isExpanded,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onToggle,
    required this.onCreateSubfolder,
    required this.onRename,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final VirtualFolder folder;
  final int depth;
  final bool isExpanded;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onToggle;
  final VoidCallback onCreateSubfolder;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: 16.0 * depth, right: 12),
      leading: Icon(isExpanded ? Icons.folder_open : Icons.folder),
      title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'new':
              onCreateSubfolder();
              break;
            case 'rename':
              onRename();
              break;
            case 'delete':
              onDelete();
              break;
            case 'up':
              onMoveUp();
              break;
            case 'down':
              onMoveDown();
              break;
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'new',
            child: ListTile(
              leading: Icon(Icons.create_new_folder_outlined),
              title: Text('New subfolder'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'rename',
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Rename'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'up',
            enabled: canMoveUp,
            child: const ListTile(
              leading: Icon(Icons.arrow_upward),
              title: Text('Move up'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: 'down',
            enabled: canMoveDown,
            child: const ListTile(
              leading: Icon(Icons.arrow_downward),
              title: Text('Move down'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Delete'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      onTap: onToggle,
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.indent,
    required this.isLiked,
    required this.onTap,
    required this.onLongPress,
  });

  final UiTrack track;
  final int indent;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: 16.0 * indent, right: 12),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(track.artistName, maxLines: 1),
      trailing: Icon(
        isLiked ? Icons.favorite : Icons.favorite_border,
        color: isLiked ? Colors.red : null,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class _FolderChoiceRow extends StatelessWidget {
  const _FolderChoiceRow({
    required this.folder,
    required this.depth,
    required this.isSelected,
    required this.onTap,
  });

  final VirtualFolder folder;
  final int depth;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.only(left: 16.0 * depth, right: 12),
      leading: const Icon(Icons.folder_outlined),
      title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: onTap,
    );
  }
}

String _basename(String path) {
  if (path.isEmpty) return path;
  final parts = path.split(RegExp(r'[\\/]+')).where((part) => part.isNotEmpty);
  return parts.isEmpty ? path : parts.last;
}
