# SicBy UI Implementation Plan - Phase 3

> **Agent**: Copilot (UI/UX)
> **Branch**: `phase3-ui-planning`
> **Status**: Scaffolding Complete

---

## 1. Folder Structure

```
lib/
├── main.dart
├── routes/
│   └── app_router.dart       # GoRouter config
├── state/
│   └── controllers.dart      # State controller barrel
├── ui/
│   ├── navigation/
│   │   └── main_shell.dart   # Adaptive shell
│   ├── screens/
│   │   ├── screens.dart      # Barrel export
│   │   ├── library_screen.dart
│   │   ├── now_playing_screen.dart
│   │   ├── queue_screen.dart
│   │   ├── search_screen.dart
│   │   └── settings_screen.dart
│   ├── theme/
│   │   └── app_theme.dart    # Dark theme config
│   └── widgets/
│       └── widgets.dart      # Widget barrel
```

---

## 2. Implementation Order

| Phase | Component | Dependencies |
|-------|-----------|--------------|
| 3.1 | `app_theme.dart` | None |
| 3.2 | `main_shell.dart` | Theme |
| 3.3 | `app_router.dart` | Shell, Screens |
| 3.4 | Core Widgets | Theme |
| 3.5 | Screen Implementation | Widgets, Controllers |

---

## 3. Screen → Controller Contracts

| Screen | Controller | Data Required |
|--------|------------|---------------|
| Library | `LibraryController` | `List<UiAlbum>`, `List<UiArtist>`, `List<UiTrack>` |
| NowPlaying | `PlaybackController` | `UiPlaybackState` |
| Queue | `QueueController` | `List<UiTrack>` |
| Search | `SearchController` | `List<UiSearchResult>` |
| Settings | `SettingsController` | `UserSettings` |

---

## 4. Dependencies on CodeX

| UI Need | Backend Interface Required |
|---------|---------------------------|
| Track list data | `LibraryIndex.getTracks()` |
| Album artwork | `MediaFileAccess.getArtwork(id, size)` |
| Playback control | `PlaybackService.play/pause/seek` |
| Search | `LibraryIndex.search(query)` |

---

## 5. Open Items

- [ ] Confirm `go_router` and `flutter_riverpod` added to pubspec
- [ ] Await CodeX's Repository interfaces for controller implementation
- [ ] Design MiniPlayer widget dimensions

