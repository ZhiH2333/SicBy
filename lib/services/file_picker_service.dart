import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

/// 跨平台文件选择器服务
/// 支持 macOS、Android、Windows、Web
class FilePickerService {
  /// 弹出系统文件夹选择器（仅支持桌面和移动平台）
  /// 返回选中的文件夹路径，如果取消则返回 null
  static Future<String?> pickDirectory({
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    try {
      final path = await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle ?? 'Select a Folder',
        initialDirectory: initialDirectory,
        lockParentWindow: !kIsWeb,
      );
      return path;
    } catch (e) {
      debugPrint('Error picking directory: $e');
      return null;
    }
  }

  /// 弹出系统文件选择器（单个文件）
  /// 可选择文件类型和扩展名
  /// 返回选中的文件路径，如果取消则返回 null
  static Future<String?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
        lockParentWindow: !kIsWeb,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      return result.files.first.path;
    } catch (e) {
      debugPrint('Error picking file: $e');
      return null;
    }
  }

  /// 弹出系统文件选择器（多个文件）
  /// 可选择文件类型和扩展名
  /// 返回选中的文件路径列表，如果取消则返回空列表
  static Future<List<String>> pickMultipleFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: dialogTitle,
        initialDirectory: initialDirectory,
        type: type,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
        lockParentWindow: !kIsWeb,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      return result.files
          .map((file) => file.path)
          .whereType<String>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('Error picking files: $e');
      return [];
    }
  }

  /// 弹出系统音乐文件选择器（单个文件）
  static Future<String?> pickAudioFile({
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    return pickFile(
      dialogTitle: dialogTitle ?? 'Select an Audio File',
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'flac',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'opus',
      ],
    );
  }

  /// 弹出系统音乐文件选择器（多个文件）
  static Future<List<String>> pickAudioFiles({
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    return pickMultipleFiles(
      dialogTitle: dialogTitle ?? 'Select Audio Files',
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: [
        'mp3',
        'flac',
        'wav',
        'm4a',
        'aac',
        'ogg',
        'opus',
      ],
    );
  }

  /// 弹出系统图片文件选择器（单个文件）
  static Future<String?> pickImageFile({
    String? dialogTitle,
    String? initialDirectory,
  }) async {
    return pickFile(
      dialogTitle: dialogTitle ?? 'Select an Image',
      initialDirectory: initialDirectory,
      type: FileType.image,
    );
  }

  /// 检查当前平台是否支持文件夹选择
  static bool get supportsFolderSelection => !kIsWeb;

  /// 检查当前平台是否支持文件选择
  static bool get supportsFileSelection => true;

  /// 获取平台名称
  static String get platformName {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.macOS:
        return 'macOS';
      case TargetPlatform.windows:
        return 'Windows';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }
}
