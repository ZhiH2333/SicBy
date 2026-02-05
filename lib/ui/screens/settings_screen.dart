import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sicby/state/local_library_provider.dart';
import 'package:sicby/state/settings_controller.dart';

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

    return _Section(
      title: 'Library',
      children: [
        ListTile(
          title: const Text('Music Folders'),
          subtitle: Text(
            libraryState.scannedPaths.isEmpty
                ? 'No folders selected'
                : '${libraryState.scannedPaths.length} folders',
          ),
          trailing: TextButton(
            onPressed: () => libraryController.pickAndAddFolder(),
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
        SwitchListTile(
          title: const Text('Scan recursively'),
          value: settingsState.settings.scanRecursively,
          onChanged: (value) => settingsController.setScanRecursively(value),
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

    return _Section(
      title: 'Playback',
      children: [
        SwitchListTile(
          title: const Text('Gapless Playback'),
          subtitle: const Text('Preload next track'),
          value: settingsState.settings.gaplessEnabled,
          onChanged: (value) => settingsController.setGaplessEnabled(value),
        ),
        SwitchListTile(
          title: const Text('Lyrics'),
          subtitle: const Text('Enable local lyrics view'),
          value: settingsState.settings.lyricsEnabled,
          onChanged: (value) => settingsController.setLyricsEnabled(value),
        ),
        ListTile(
          title: const Text('Playback Speed'),
          trailing: DropdownButton<double>(
            value: settingsState.settings.playbackSpeed,
            underline: const SizedBox(),
            items: [0.5, 1.0, 1.25, 1.5, 2.0].map((speed) {
              return DropdownMenuItem(value: speed, child: Text('${speed}x'));
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                settingsController.setPlaybackSpeed(value);
              }
            },
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

    return _Section(
      title: 'Appearance',
      children: [
        ListTile(
          title: const Text('Theme Mode'),
          trailing: DropdownButton<String>(
            value: settingsState.settings.themeMode,
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'system', child: Text('System')),
              DropdownMenuItem(value: 'dark', child: Text('Dark')),
              DropdownMenuItem(value: 'light', child: Text('Light')),
            ],
            onChanged: (value) {
              if (value != null) {
                settingsController.setThemeMode(value);
              }
            },
          ),
        ),
        ListTile(
          title: const Text('Accent Color'),
          trailing: Wrap(
            spacing: 8,
            children: [
              _ColorDot(
                color: const Color(0xFF00F0A8),
                isSelected: settingsState.settings.accentColor == 0xFF00F0A8,
                onTap: () => settingsController.setAccentColor(0xFF00F0A8),
              ),
              _ColorDot(
                color: Colors.blueAccent,
                isSelected:
                    settingsState.settings.accentColor ==
                    // ignore: deprecated_member_use
                    Colors.blueAccent.value,
                onTap: () => settingsController.setAccentColor(
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
                onTap: () => settingsController.setAccentColor(
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
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: isSelected
              ? [BoxShadow(color: color.withAlpha(100), blurRadius: 4)]
              : null,
        ),
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
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              children: _withDividers(children),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _withDividers(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) {
        out.add(Divider(height: 1, color: Colors.grey[800]));
      }
    }
    return out;
  }
}
