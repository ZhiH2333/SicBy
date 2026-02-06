class AppSettings {
  static const int currentVersion = 7;

  final int version;
  final bool scanRecursively;
  final bool includeHiddenFiles;
  final bool rememberLastFolder;
  final double playbackSpeed;
  final bool gaplessEnabled;
  final String themeMode; // 'system', 'light', 'dark'
  final int accentColor; // Color value
  final bool shuffleDefault;
  final String repeatModeDefault; // 'off', 'all', 'one'
  final bool autoRefreshOnLaunch;
  final String metadataMode; // 'metadata', 'file'
  final bool autoDownloadCloudTracks;
  final bool showCloudOnlyTracks;
  final bool autoDownloadOnPlay;
  final bool resumeAfterDownload;
  final bool disableSwitchDuringDownload;
  final List<String> libraryPaths;
  final bool lyricsEnabled;

  const AppSettings({
    required this.version,
    required this.scanRecursively,
    required this.includeHiddenFiles,
    required this.rememberLastFolder,
    required this.playbackSpeed,
    required this.gaplessEnabled,
    required this.themeMode,
    required this.accentColor,
    required this.shuffleDefault,
    required this.repeatModeDefault,
    required this.autoRefreshOnLaunch,
    required this.metadataMode,
    required this.autoDownloadCloudTracks,
    required this.showCloudOnlyTracks,
    required this.autoDownloadOnPlay,
    required this.resumeAfterDownload,
    required this.disableSwitchDuringDownload,
    required this.libraryPaths,
    required this.lyricsEnabled,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      version: currentVersion,
      scanRecursively: true,
      includeHiddenFiles: false,
      rememberLastFolder: true,
      playbackSpeed: 1.0,
      gaplessEnabled: false,
      themeMode: 'dark',
      accentColor: 0xFF1DB954, // Spotify Green
      shuffleDefault: false,
      repeatModeDefault: 'off',
      autoRefreshOnLaunch: true,
      metadataMode: 'metadata',
      autoDownloadCloudTracks: true,
      showCloudOnlyTracks: true,
      autoDownloadOnPlay: true,
      resumeAfterDownload: true,
      disableSwitchDuringDownload: true,
      libraryPaths: [],
      lyricsEnabled: true,
    );
  }

  AppSettings copyWith({
    int? version,
    bool? scanRecursively,
    bool? includeHiddenFiles,
    bool? rememberLastFolder,
    double? playbackSpeed,
    bool? gaplessEnabled,
    String? themeMode,
    int? accentColor,
    bool? shuffleDefault,
    String? repeatModeDefault,
    bool? autoRefreshOnLaunch,
    String? metadataMode,
    bool? autoDownloadCloudTracks,
    bool? showCloudOnlyTracks,
    bool? autoDownloadOnPlay,
    bool? resumeAfterDownload,
    bool? disableSwitchDuringDownload,
    List<String>? libraryPaths,
    bool? lyricsEnabled,
  }) {
    return AppSettings(
      version: version ?? this.version,
      scanRecursively: scanRecursively ?? this.scanRecursively,
      includeHiddenFiles: includeHiddenFiles ?? this.includeHiddenFiles,
      rememberLastFolder: rememberLastFolder ?? this.rememberLastFolder,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      gaplessEnabled: gaplessEnabled ?? this.gaplessEnabled,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      shuffleDefault: shuffleDefault ?? this.shuffleDefault,
      repeatModeDefault: repeatModeDefault ?? this.repeatModeDefault,
      autoRefreshOnLaunch: autoRefreshOnLaunch ?? this.autoRefreshOnLaunch,
      metadataMode: metadataMode ?? this.metadataMode,
      autoDownloadCloudTracks:
          autoDownloadCloudTracks ?? this.autoDownloadCloudTracks,
      showCloudOnlyTracks: showCloudOnlyTracks ?? this.showCloudOnlyTracks,
      autoDownloadOnPlay: autoDownloadOnPlay ?? this.autoDownloadOnPlay,
      resumeAfterDownload: resumeAfterDownload ?? this.resumeAfterDownload,
      disableSwitchDuringDownload:
          disableSwitchDuringDownload ?? this.disableSwitchDuringDownload,
      libraryPaths: libraryPaths ?? this.libraryPaths,
      lyricsEnabled: lyricsEnabled ?? this.lyricsEnabled,
    );
  }

  Map<String, Object> toMap() {
    return {
      'version': version,
      'scanRecursively': scanRecursively,
      'includeHiddenFiles': includeHiddenFiles,
      'rememberLastFolder': rememberLastFolder,
      'playbackSpeed': playbackSpeed,
      'gaplessEnabled': gaplessEnabled,
      'themeMode': themeMode,
      'accentColor': accentColor,
      'shuffleDefault': shuffleDefault,
      'repeatModeDefault': repeatModeDefault,
      'autoRefreshOnLaunch': autoRefreshOnLaunch,
      'metadataMode': metadataMode,
      'autoDownloadCloudTracks': autoDownloadCloudTracks,
      'showCloudOnlyTracks': showCloudOnlyTracks,
      'autoDownloadOnPlay': autoDownloadOnPlay,
      'resumeAfterDownload': resumeAfterDownload,
      'disableSwitchDuringDownload': disableSwitchDuringDownload,
      'libraryPaths': libraryPaths,
      'lyricsEnabled': lyricsEnabled,
    };
  }

  factory AppSettings.fromMap(Map<String, Object?> map) {
    return AppSettings(
      version: map['version'] as int? ?? currentVersion,
      scanRecursively: map['scanRecursively'] as bool? ?? true,
      includeHiddenFiles: map['includeHiddenFiles'] as bool? ?? false,
      rememberLastFolder: map['rememberLastFolder'] as bool? ?? true,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      gaplessEnabled: map['gaplessEnabled'] as bool? ?? false,
      themeMode: map['themeMode'] as String? ?? 'dark',
      accentColor: map['accentColor'] as int? ?? 0xFF1DB954,
      shuffleDefault: map['shuffleDefault'] as bool? ?? false,
      repeatModeDefault: map['repeatModeDefault'] as String? ?? 'off',
      autoRefreshOnLaunch: map['autoRefreshOnLaunch'] as bool? ?? true,
      metadataMode: map['metadataMode'] as String? ?? 'metadata',
      autoDownloadCloudTracks: map['autoDownloadCloudTracks'] as bool? ?? true,
      showCloudOnlyTracks: map['showCloudOnlyTracks'] as bool? ?? true,
      autoDownloadOnPlay: map['autoDownloadOnPlay'] as bool? ?? true,
      resumeAfterDownload: map['resumeAfterDownload'] as bool? ?? true,
      disableSwitchDuringDownload:
          map['disableSwitchDuringDownload'] as bool? ?? true,
      libraryPaths:
          (map['libraryPaths'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      lyricsEnabled: map['lyricsEnabled'] as bool? ?? true,
    );
  }
}

class SettingsState {
  final AppSettings settings;
  final bool isLoading;
  final String? error;

  const SettingsState({
    required this.settings,
    this.isLoading = false,
    this.error,
  });

  factory SettingsState.initial() {
    return SettingsState(settings: AppSettings.defaults());
  }

  SettingsState copyWith({
    AppSettings? settings,
    bool? isLoading,
    String? error,
  }) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
