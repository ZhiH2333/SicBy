import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/features/metadata_test/metadata_test_screen.dart';
import 'package:sicby/state/local_library_provider.dart';
import 'package:sicby/state/settings_controller.dart';
import 'package:sicby/state/service_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: const [
          _LibrarySection(),
          _PlaybackSection(),
          _AppearanceSection(),
          _AboutSection(),
        ],
      ),
    );
  }
}

class _LibrarySection extends ConsumerWidget {
  const _LibrarySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libraryState = ref.watch(localLibraryProvider);
    final settingsState = ref.watch(settingsControllerProvider);
    final libraryController = ref.read(localLibraryProvider.notifier);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final capabilities = ref.watch(capabilityFlagsProvider);

    return _Section(
      title: 'Library',
      children: [
        ListTile(
          title: const Text('Music Folders'),
          subtitle: Text(
            !capabilities.supportsFolderSelection
                ? 'Folder selection not supported on this platform'
                : libraryState.scannedPaths.isEmpty
                ? 'No folders selected'
                : '${libraryState.scannedPaths.length} folders',
          ),
          trailing: TextButton(
            onPressed: capabilities.supportsFolderSelection
                ? () => libraryController.pickAndAddFolder()
                : null,
            child: const Text('ADD'),
          ),
        ),
        ...libraryState.scannedPaths.map(
          (path) => ListTile(
            title: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => libraryController.removeLibraryPath(path),
            ),
          ),
        ),
        ListTile(
          title: const Text('Rescan Library'),
          subtitle: Text(
            libraryState.scannedPaths.isEmpty
                ? 'Add a folder to enable scanning'
                : 'Refresh local library index',
          ),
          trailing: TextButton(
            onPressed: libraryState.scannedPaths.isNotEmpty
                ? () => libraryController.scanFromSettings()
                : null,
            child: const Text('RESCAN'),
          ),
        ),
        SwitchListTile(
          title: const Text('Scan recursively'),
          subtitle: const Text('Include subfolders when scanning'),
          value: settingsState.settings.scanRecursively,
          onChanged: (value) => settingsController.setScanRecursively(value),
        ),
        SwitchListTile(
          title: const Text('Auto-refresh on launch'),
          subtitle: const Text('Rescan library when the app opens'),
          value: settingsState.settings.autoRefreshOnLaunch,
          onChanged: (value) =>
              settingsController.setAutoRefreshOnLaunch(value),
        ),
        ListTile(
          title: const Text('Metadata mode'),
          subtitle: const Text('Choose between file name or embedded tags'),
          trailing: DropdownButton<String>(
            value: settingsState.settings.metadataMode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'metadata', child: Text('Metadata')),
              DropdownMenuItem(value: 'file', child: Text('File')),
            ],
            onChanged: (value) {
              if (value != null) {
                settingsController.setMetadataMode(value);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _PlaybackSection extends ConsumerWidget {
  const _PlaybackSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final capabilities = ref.watch(capabilityFlagsProvider);

    return _Section(
      title: 'Playback',
      children: [
        SwitchListTile(
          title: const Text('Gapless Playback'),
          subtitle: Text(
            capabilities.supportsGapless
                ? 'Preload next track'
                : 'Not supported on this platform yet',
          ),
          value: settingsState.settings.gaplessEnabled,
          onChanged: capabilities.supportsGapless
              ? (value) => settingsController.setGaplessEnabled(value)
              : null,
        ),
        SwitchListTile(
          title: const Text('Shuffle by default'),
          subtitle: const Text('Start playback with shuffle enabled'),
          value: settingsState.settings.shuffleDefault,
          onChanged: (value) => settingsController.setShuffleDefault(value),
        ),
        ListTile(
          title: const Text('Repeat by default'),
          subtitle: const Text('Choose default repeat mode'),
          trailing: DropdownButton<String>(
            value: settingsState.settings.repeatModeDefault,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'off', child: Text('Off')),
              DropdownMenuItem(value: 'all', child: Text('Repeat All')),
              DropdownMenuItem(value: 'one', child: Text('Repeat One')),
            ],
            onChanged: (value) {
              if (value != null) {
                settingsController.setRepeatModeDefault(value);
              }
            },
          ),
        ),
        SwitchListTile(
          title: const Text('Lyrics'),
          subtitle: const Text('Enable local lyrics view'),
          value: settingsState.settings.lyricsEnabled,
          onChanged: (value) => settingsController.setLyricsEnabled(value),
        ),
        ListTile(
          title: const Text('Playback Speed'),
          subtitle: Text(
            capabilities.supportsPlaybackSpeed
                ? 'Adjust speed without pitch change'
                : 'Not supported on this platform yet',
          ),
          trailing: DropdownButton<double>(
            value: settingsState.settings.playbackSpeed,
            underline: const SizedBox(),
            items: [0.5, 1.0, 1.25, 1.5, 2.0].map((speed) {
              return DropdownMenuItem(value: speed, child: Text('${speed}x'));
            }).toList(),
            onChanged: capabilities.supportsPlaybackSpeed
                ? (value) {
                    if (value != null) {
                      settingsController.setPlaybackSpeed(value);
                    }
                  }
                : null,
          ),
        ),
      ],
    );
  }
}

class _AppearanceSection extends ConsumerWidget {
  const _AppearanceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsControllerProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    const themeDisabled = true;

    return _Section(
      title: 'Appearance',
      children: [
        ListTile(
          title: const Text('Theme Mode'),
          subtitle: const Text('Theme system unlocks after core setup'),
          trailing: DropdownButton<String>(
            value: settingsState.settings.themeMode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
            ],
            onChanged: themeDisabled
                ? null
                : (value) {
                    if (value != null) {
                      settingsController.setThemeMode(value);
                    }
                  },
          ),
        ),
        ListTile(
          title: const Text('Accent Color'),
          subtitle: const Text('Available after theme system is enabled'),
          trailing: Wrap(
            spacing: 8,
            children: [
              _ColorDot(
                color: const Color(0xFF00F0A8),
                isSelected: settingsState.settings.accentColor == 0xFF00F0A8,
                onTap:
                    themeDisabled
                        ? null
                        : () =>
                            settingsController.setAccentColor(0xFF00F0A8),
              ),
              _ColorDot(
                color: Colors.blueAccent,
                isSelected:
                    settingsState.settings.accentColor ==
                    // ignore: deprecated_member_use
                    Colors.blueAccent.value,
                onTap: themeDisabled
                    ? null
                    : () => settingsController.setAccentColor(
                      // ignore: deprecated_member_use
                      Colors.blueAccent.value,
                    ),
              ),
              _ColorDot(
                color: Colors.purpleAccent,
                isSelected:
                    settingsState.settings.accentColor ==
                    // ignore: deprecated_member_use
                    Colors.purpleAccent.value,
                onTap: themeDisabled
                    ? null
                    : () => settingsController.setAccentColor(
                      // ignore: deprecated_member_use
                      Colors.purpleAccent.value,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: scheme.onSurface, width: 2)
              : null,
          boxShadow: isSelected
              ? [BoxShadow(color: color.withAlpha(100), blurRadius: 4)]
              : null,
        ),
        foregroundDecoration: onTap == null
            ? BoxDecoration(
                color: scheme.surface.withAlpha(120),
                shape: BoxShape.circle,
              )
            : null,
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'About',
      children: [
        ListTile(
          title: const Text('Metadata Test'),
          subtitle: const Text('Verify extraction and cache behavior'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const MetadataTestScreen(),
              ),
            );
          },
        ),
        ListTile(
          title: const Text('Version'),
          trailing: const Text('1.0.0 (Phase 6)'),
        ),
        ListTile(
          title: const Text('Open Source Licenses'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            showLicensePage(context: context);
          },
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Grouped section with subtle background and dividers to match
    // Spotify-like visual grouping and consistent spacing.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(children: _withDividers(children, scheme)),
          ),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> items, ColorScheme scheme) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(Divider(height: 1, color: scheme.outline));
      }
    }
    return out;
  }
}
