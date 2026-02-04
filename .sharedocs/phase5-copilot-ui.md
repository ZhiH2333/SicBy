# Phase 5: UI Refinement & Settings Planning

> **Agent**: Copilot (UI/UX)
> **Branch**: `phase5-ui-refinement`
> **Goal**: Polish UI visuals and implement Settings functionality.

---

## 1. UI Refinement Strategy

### Visual Language ("Pulse" Theme V2)
- **Hierarchy**: Use `TextTheme` consistently.
  - `Display`: Hero text (Now Playing titles)
  - `Headline`: Section headers (Library, Settings groups)
  - `Body`: List items
  - `Label`: Metadata (Artist names, durations)
- **Spacing**: strict 4pt grid (8, 16, 24, 32).
- **Feedback**: Add `InkWell` / `Material` ripples to all interactables.

### Animations
- **Transitions**:
  - `PageTransitionsTheme`: ZoomPageTransition (Android), Cupertino (iOS).
  - Use `FadeTransition` for image loading.
- **Hero**:
  - Album art from Library -> Now Playing.
  - MiniPlayer -> Now Playing (expand animation).

---

## 2. Settings Architecture

### Controller
`SettingsController` managing `UiSettingsState`.
Persisted via `shared_preferences` (or Hive if available) - *Constraint: UI only talks to Controller*.

### State Model
```dart
class UiSettingsState {
  final ThemeMode themeMode;
  final bool compactMode;
  final bool showUnsupportedFiles;
  final bool autoRescan;
  final String? version;
}
```

### Screens structure
```
SettingsScreen
├── LibrarySection
│   ├── FolderListTile (trailing: remove)
│   ├── AddFolderButton
│   ├── AutoRescanSwitch
│   └── RescanNowButton
├── AppearanceSection
│   ├── ThemeDropdown (Dark/System)
│   └── CompactModeSwitch (Desktop only)
└── AboutSection
    ├── VersionTile
    └── LicensesTile
```

---

## 3. Implementation Plan

### Step 1: Foundation
1. Create `SettingsController` & `UiSettingsState`.
2. Update `AppTheme` with refined text styles and component themes.
3. Add `animations` package (optional, or use built-in).

### Step 2: Settings UI
1. Implement `SettingsScreen` with sections.
2. Wire up `LibraryController` for folder management.
3. Wire up `SettingsController` for theme/prefs.

### Step 3: Visual Polish
1. Update `NowPlayingScreen`:
   - Better gradients / blur background.
   - Animated play/pause button.
2. Update `LibraryScreen`:
   - Better empty states.
   - Smooth image loading.
3. Update `MiniPlayer`:
   - Progress bar smooth animation.

---

## 4. Dependencies & Risks

- **Gapless Playback**: Backend dependent. UI will show toggle if supported, else disabled.
- **Resume on Launch**: Requires persistence of last played track. (Will mock or store in generic prefs).
- **Desktop Window**: Window Manager needed for "Minimize to Tray". Will skip for now (UI-only scope).

