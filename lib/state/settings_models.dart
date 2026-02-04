class AppSettings {
  static const int currentVersion = 1;

  final int version;
  final bool scanRecursively;
  final bool includeHiddenFiles;
  final bool rememberLastFolder;
  final double playbackSpeed;
  final bool gaplessEnabled;

  const AppSettings({
    required this.version,
    required this.scanRecursively,
    required this.includeHiddenFiles,
    required this.rememberLastFolder,
    required this.playbackSpeed,
    required this.gaplessEnabled,
  });

  factory AppSettings.defaults() {
    return const AppSettings(
      version: currentVersion,
      scanRecursively: true,
      includeHiddenFiles: false,
      rememberLastFolder: true,
      playbackSpeed: 1.0,
      gaplessEnabled: false,
    );
  }

  AppSettings copyWith({
    int? version,
    bool? scanRecursively,
    bool? includeHiddenFiles,
    bool? rememberLastFolder,
    double? playbackSpeed,
    bool? gaplessEnabled,
  }) {
    return AppSettings(
      version: version ?? this.version,
      scanRecursively: scanRecursively ?? this.scanRecursively,
      includeHiddenFiles: includeHiddenFiles ?? this.includeHiddenFiles,
      rememberLastFolder: rememberLastFolder ?? this.rememberLastFolder,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      gaplessEnabled: gaplessEnabled ?? this.gaplessEnabled,
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
