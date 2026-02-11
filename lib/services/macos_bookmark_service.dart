import 'dart:io';

import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// macOS 安全范围书签服务
/// 用于持久化文件夹访问权限
class MacOsBookmarkService {
  static const _keyPrefix = 'macos_bookmark_';
  final SecureBookmarks _secureBookmarks = SecureBookmarks();

  /// 为文件夹路径创建并保存书签
  Future<bool> saveBookmarkForPath(String path) async {
    if (!Platform.isMacOS) return true;

    try {
      final bookmark = await _secureBookmarks.bookmark(File(path));
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForPath(path);
      await prefs.setString(key, bookmark);
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ [Bookmark] Failed to save bookmark for $path: $e');
      return false;
    }
  }

  /// 从书签恢复文件夹访问权限
  Future<bool> restoreAccessForPath(String path) async {
    if (!Platform.isMacOS) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForPath(path);
      final bookmark = prefs.getString(key);

      if (bookmark == null) {
        // ignore: avoid_print
        print('⚠️ [Bookmark] No bookmark found for $path');
        return false;
      }

      final file = await _secureBookmarks.resolveBookmark(bookmark);

      // 开始访问安全范围资源
      await _secureBookmarks.startAccessingSecurityScopedResource(file);
      // ignore: avoid_print
      print('✅ [Bookmark] Restored access for $path');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('❌ [Bookmark] Failed to restore access for $path: $e');
      return false;
    }
  }

  /// 为所有保存的路径恢复访问权限
  Future<Map<String, bool>> restoreAccessForPaths(List<String> paths) async {
    if (!Platform.isMacOS) {
      return {for (final path in paths) path: true};
    }

    final results = <String, bool>{};
    for (final path in paths) {
      results[path] = await restoreAccessForPath(path);
    }
    return results;
  }

  /// 删除路径的书签
  Future<void> removeBookmarkForPath(String path) async {
    if (!Platform.isMacOS) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _keyForPath(path);
      await prefs.remove(key);
      // ignore: avoid_print
      print('🗑️ [Bookmark] Removed bookmark for $path');
    } catch (e) {
      // ignore: avoid_print
      print('❌ [Bookmark] Failed to remove bookmark for $path: $e');
    }
  }

  /// 停止访问安全范围资源
  Future<void> stopAccessingPath(String path) async {
    if (!Platform.isMacOS) return;

    try {
      final file = File(path);
      await _secureBookmarks.stopAccessingSecurityScopedResource(file);
      // ignore: avoid_print
      print('🛑 [Bookmark] Stopped accessing $path');
    } catch (e) {
      // ignore: avoid_print
      print('❌ [Bookmark] Failed to stop accessing $path: $e');
    }
  }

  /// 生成路径对应的存储键
  String _keyForPath(String path) {
    // 使用路径的哈希作为键，避免特殊字符问题
    return '$_keyPrefix${path.hashCode}';
  }

  /// 检查是否已有书签
  Future<bool> hasBookmarkForPath(String path) async {
    if (!Platform.isMacOS) return false;

    final prefs = await SharedPreferences.getInstance();
    final key = _keyForPath(path);
    return prefs.containsKey(key);
  }

  /// 清除所有书签（用于调试）
  Future<void> clearAllBookmarks() async {
    if (!Platform.isMacOS) return;

    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
    // ignore: avoid_print
    print('🗑️ [Bookmark] Cleared all bookmarks');
  }
}
