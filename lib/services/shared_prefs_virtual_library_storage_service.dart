import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../state/virtual_library_models.dart';
import 'virtual_library_storage_service.dart';

class SharedPrefsVirtualLibraryStorageService
    implements VirtualLibraryStorageService {
  static const _keyFolders = 'virtual_library_folders';
  static const _keyAssignments = 'virtual_library_assignments';

  @override
  Future<VirtualLibrarySnapshot> read() async {
    final prefs = await SharedPreferences.getInstance();
    final foldersRaw = prefs.getString(_keyFolders);
    final assignmentsRaw = prefs.getString(_keyAssignments);

    final folders = <VirtualFolder>[];
    if (foldersRaw != null && foldersRaw.isNotEmpty) {
      final decoded = jsonDecode(foldersRaw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            folders.add(
              VirtualFolder.fromMap(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            );
          }
        }
      }
    }

    final assignments = <String, String?>{};
    if (assignmentsRaw != null && assignmentsRaw.isNotEmpty) {
      final decoded = jsonDecode(assignmentsRaw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          assignments[key.toString()] = value?.toString();
        });
      }
    }

    return VirtualLibrarySnapshot(folders: folders, assignments: assignments);
  }

  @override
  Future<void> write(VirtualLibrarySnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final foldersJson = jsonEncode(
      snapshot.folders.map((folder) => folder.toMap()).toList(),
    );
    final assignmentsJson = jsonEncode(snapshot.assignments);
    await prefs.setString(_keyFolders, foldersJson);
    await prefs.setString(_keyAssignments, assignmentsJson);
  }

  @override
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFolders);
    await prefs.remove(_keyAssignments);
  }
}
