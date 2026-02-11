# macOS 沙盒文件访问权限修复

## 🐛 问题描述

应用在 macOS 沙盒环境下，关闭后重新打开时无法加载音乐目录：
- ✅ 目录能显示
- ❌ 点击播放失败
- ✅ 删除后重新添加才能播放
- ✅ 退出后问题重现

## 🔍 根本原因

macOS 沙盒应用对文件访问有严格限制：

1. **临时权限**：用户通过文件选择器选择文件夹时，macOS 授予临时访问权限
2. **权限失效**：应用关闭后，访问权限自动失效
3. **路径无效**：重新打开时，虽然数据库中保存了路径，但无权访问
4. **需要书签**：必须使用 Security-Scoped Bookmarks 来持久化访问权限

## ✅ 解决方案

### 修改内容

#### 1. 添加依赖 (pubspec.yaml)
```yaml
macos_secure_bookmarks: ^0.2.1
```

#### 2. 更新 macOS 权限配置
- `macos/Runner/Release.entitlements`
- `macos/Runner/DebugProfile.entitlements`

添加书签权限：
```xml
<key>com.apple.security.files.bookmarks.app-scope</key>
<true/>
```

#### 3. 创建书签服务 (lib/services/macos_bookmark_service.dart)
- `saveBookmarkForPath()` - 保存文件夹访问书签
- `restoreAccessForPath()` - 恢复文件夹访问权限
- `restoreAccessForPaths()` - 批量恢复权限
- `removeBookmarkForPath()` - 删除书签

#### 4. 集成到文件夹管理 (lib/state/local_library_provider.dart)
- 添加文件夹时自动保存书签
- 应用启动时自动恢复访问权限
- 删除文件夹时清理书签

#### 5. 修复启动逻辑 (lib/ui/navigation/main_shell.dart)
修正 `autoRefreshOnLaunch` 逻辑错误（之前逻辑是反的）

### 工作流程

```
┌─────────────────────────────────────────────────────────────┐
│ 用户添加文件夹                                               │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ├──> 1. 系统文件选择器 (file_picker)
                    │
                    ├──> 2. 获取文件夹路径
                    │
                    ├──> 3. 创建安全范围书签 (bookmark)
                    │
                    ├──> 4. 保存书签到 SharedPreferences
                    │
                    ├──> 5. 保存路径到设置
                    │
                    └──> 6. 扫描文件夹

┌─────────────────────────────────────────────────────────────┐
│ 应用重新启动                                                 │
└───────────────────┬─────────────────────────────────────────┘
                    │
                    ├──> 1. 加载设置中的文件夹路径
                    │
                    ├──> 2. 从 SharedPreferences 读取书签
                    │
                    ├──> 3. 解析书签恢复文件访问权限
                    │         (startAccessingSecurityScopedResource)
                    │
                    ├──> 4. 加载数据库中的音乐
                    │
                    └──> 5. 重新扫描文件系统 (如果 autoRefreshOnLaunch=true)
```

## 🧪 测试步骤

### 1. 清理测试

```bash
# 删除应用数据（重置状态）
rm -rf ~/Library/Containers/com.example.sicby/
```

### 2. 构建并运行

```bash
flutter clean
flutter pub get
flutter run -d macos
```

### 3. 测试场景

#### 场景 A：首次添加文件夹
1. ✅ 启动应用
2. ✅ 添加音乐文件夹
3. ✅ 播放音乐正常
4. ✅ 检查控制台输出：
   ```
   ✅ [Bookmark] Restored access for /path/to/music
   ```

#### 场景 B：重启应用
1. ✅ 完全退出应用
2. ✅ 重新打开应用
3. ✅ 检查控制台输出：
   ```
   📂 [Library] Restoring access for 1 folders...
   ✅ [Bookmark] Restored access for /path/to/music
   ```
4. ✅ 音乐列表显示
5. ✅ 点击播放正常工作 ⭐ **关键测试**

#### 场景 C：多次重启
1. ✅ 重复关闭和打开应用 3-5 次
2. ✅ 每次都能正常播放

#### 场景 D：多个文件夹
1. ✅ 添加 2-3 个不同的音乐文件夹
2. ✅ 重启应用
3. ✅ 所有文件夹的音乐都能播放

#### 场景 E：删除文件夹
1. ✅ 从设置中删除一个文件夹
2. ✅ 检查控制台输出：
   ```
   🗑️ [Bookmark] Removed bookmark for /path/to/music
   ```
3. ✅ 该文件夹的音乐消失

## 📊 预期结果

### ✅ 成功指标
- [ ] 应用重启后音乐列表正常显示
- [ ] 点击播放立即工作，无需重新添加
- [ ] 控制台日志显示书签恢复成功
- [ ] 多次重启稳定工作

### ❌ 失败场景处理

如果书签恢复失败，控制台会显示：
```
⚠️ [Bookmark] No bookmark found for /path/to/music
```
或
```
❌ [Bookmark] Failed to restore access for /path/to/music
```

**解决方法**：
1. 用户需要删除该文件夹
2. 重新添加文件夹（这会创建新的书签）

## 🔧 调试工具

### 查看保存的书签

```dart
// 在应用中添加调试按钮
ElevatedButton(
  onPressed: () async {
    final service = MacOsBookmarkService();
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('macos_bookmark_'));
    print('Saved bookmarks: ${keys.length}');
    for (final key in keys) {
      print('  - $key: ${prefs.getString(key)?.substring(0, 50)}...');
    }
  },
  child: Text('Debug: Show Bookmarks'),
)
```

### 清除所有书签

```dart
ElevatedButton(
  onPressed: () async {
    final service = MacOsBookmarkService();
    await service.clearAllBookmarks();
    print('All bookmarks cleared');
  },
  child: Text('Debug: Clear Bookmarks'),
)
```

## 📝 技术细节

### Security-Scoped Bookmarks 工作原理

1. **Bookmark 创建**
   - 用户通过系统文件选择器选择文件/文件夹
   - 应用调用 `SecureBookmarks.bookmark(File)`
   - macOS 生成加密的书签数据（包含权限信息）

2. **Bookmark 持久化**
   - 将书签数据（String）保存到 SharedPreferences
   - 书签数据包含文件路径和访问权限

3. **权限恢复**
   - 应用启动时读取书签数据
   - 调用 `SecureBookmarks.resolveBookmark()`
   - 调用 `startAccessingSecurityScopedResource()`
   - 获得对该路径的访问权限

4. **权限释放**
   - 调用 `stopAccessingSecurityScopedResource()`（可选）
   - 应用退出时自动释放

### SharedPreferences 存储结构

```
macos_bookmark_<hashCode> -> <bookmark_data>
```

示例：
```
macos_bookmark_123456789 -> "YnBsaXN0MDDUAQIDBAUGBwpYJ..."
```

## 🚀 部署注意事项

1. **Release 构建**
   - 确保 `Release.entitlements` 包含书签权限
   - 测试 Release 模式下的行为

2. **App Store 提交**
   - 权限说明：需要访问用户选择的文件夹以播放音乐
   - 不会触发额外的审核问题（标准权限）

3. **版本迁移**
   - 老用户升级后第一次启动：没有书签，需要重新添加文件夹
   - 建议在 UI 中添加提示：
     ```
     ⚠️ 为了改善文件访问稳定性，请重新添加您的音乐文件夹
     ```

## 📚 相关资源

- [macos_secure_bookmarks](https://pub.dev/packages/macos_secure_bookmarks)
- [Apple: Security-Scoped Bookmarks](https://developer.apple.com/documentation/security/app_sandbox/accessing_files_from_the_macos_app_sandbox)
- [file_picker](https://pub.dev/packages/file_picker)

## ✨ 总结

这个修复解决了 macOS 沙盒应用的核心问题：**文件访问权限的持久化**。

通过使用 Security-Scoped Bookmarks：
- ✅ 用户只需添加文件夹一次
- ✅ 应用重启后自动恢复访问权限
- ✅ 不需要每次都重新选择文件夹
- ✅ 符合 macOS 安全规范
- ✅ App Store 合规

---

**修复完成时间**: 2026-02-11  
**测试状态**: ⏳ 待测试
