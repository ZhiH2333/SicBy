# SicBy UI/UX Architecture - Phase 2 Headers

> **Role**: Copilot (UI/UX Agent)
> **Phase**: Module Interface Definitions
> **Status**: Draft

---

## UI Modules & Screens

The UI is divided into "Shell" (persistent) and "Content" (navigable) layers.

### 1. Root Shell
**Responsibility:** Hosts the global navigation adapter, persistent player bar, and overlay manager (snackbars/dialogs).
- **Desktop**: Left Navigation Rail + Bottom Player Bar.
- **Mobile**: Bottom Navigation Bar + Mini Player (docked).
- **Web**: Similar to Desktop but sidebar may be collapsible.

### 2. Library Module
**Responsibility:** Browse and filter the local collection.
- **Screens**:
  - `LibraryHome`: Tabbed view (Playlists, Artists, Albums, Songs).
  - `AlbumDetail`: Hero header (artwork), action bar (Play, Shuffle), Tracklist.
  - `ArtistDetail`: Hero header, "Top Tracks", "Albums" grid.
  - `PlaylistDetail`: Similar to Album but with edit capabilities (reorder/remove).

### 3. Player Module
**Responsibility:** Visualization of the current playback state.
- **Screens**:
  - `NowPlayingOverlay`: Full-screen modal on Mobile; Side panel or Expanded Footer on Desktop.
  - `QueueView`: Draggable list of upcoming tracks.
  - `LyricsView`: Time-synced text display.

### 4. Search Module
**Responsibility:** Global find.
- **Screens**:
  - `SearchLanding`: Recent searches, Browse Categories (e.g., "Recently Added", "Genres" - derived from local tags).
  - `SearchResults`: Sectioned results (Songs, Artists, Albums).

### 5. Settings Module
**Responsibility**: App configuration.
- **Screens**:
  - `SettingsHome`: Sections for Appearance, Audio (backend selection), Library (Manage Scan Paths), About.

---

## UI Data Contracts

These are **View Models** customized for UI consumption. They map from Domain Entities but may include formatted strings or UI-specific flags.

### 1. Common Types
```dart
typedef ImageProviderId = String; // URI or File Path
typedef DurationMs = int;
```

### 2. UiTrack
**Purpose**: Display a single row in a tracklist or player.
```dart
class UiTrack {
  final String id;
  final String title;
  final String artistName;
  final String albumName;
  final ImageProviderId? artworkUri; // Thumbnail URL/Path
  final String durationFormatted; // e.g. "3:42"
  final bool isExplicit;
  final bool isHifi; // Bitrate > 320kbps
  final bool isPlaying; // Derived from playback state
  final bool isFavorite;
}
```

### 3. UiAlbum
**Purpose**: Display a grid item or header.
```dart
class UiAlbum {
  final String id;
  final String title;
  final String artistName;
  final ImageProviderId? artworkUri;
  final String year;
  final int trackCount;
  final String totalDurationFormatted;
}
```

### 4. UiArtist
**Purpose**: Display artist circle.
```dart
class UiArtist {
  final String id;
  final String name;
  final ImageProviderId? photoUri; // Fallback to placeholder if null
  final int albumCount;
  final int trackCount;
}
```

### 5. UiPlaybackState
**Purpose**: Drive the Now Playing screen.
```dart
class UiPlaybackState {
  final UiTrack? currentTrack;
  final bool isPlaying;
  final bool isBuffering;
  final double progressPercent; // 0.0 to 1.0 for seek bars
  final String currentPositionFormatted; // "1:15"
  final String totalDurationFormatted; // "3:42"
  final bool shuffleEnabled;
  final RepeatMode repeatMode; // off, one, all
  final double volume;
}
```

---

## UI–Controller Interaction Rules

UI widgets must **never** call Services/Repositories directly. They must use Controllers (StateNotifiers/Notifiers).

**Rule**: *Actions are Methods, State is Stream/Value.*

1.  **Library Interactions**:
    - `LibraryController.refresh()` -> Triggers rescan.
    - `LibraryController.filter(String query)` -> Updates `filteredTracks` state.

2.  **Playback Interactions**:
    - `PlaybackController.play(String trackId)` -> Clears queue, plays track.
    - `PlaybackController.queue(String trackId)` -> Adds to end of queue.
    - `PlaybackController.togglePlayPause()`
    - `PlaybackController.seekTo(double percent)`

3.  **Navigation**:
    - `RouterController.go(String route)` -> Implementation specific (GoRouter).

---

## Navigation & Layout Strategy

### 1. Breakpoints
- **Compact (`< 600dp`)**: Mobile Phone.
- **Medium (`600dp - 840dp`)**: Small Tablet / Large Foldable.
- **Expanded (`> 840dp`)**: Desktop / Large Tablet.

### 2. Layout Adapter (Responsibility: `MainShell`)
| Slot | Compact | Medium | Expanded |
| :--- | :--- | :--- | :--- |
| **Nav** | `BottomNavigationBar` | `NavigationRail` (collapsed) | `NavigationRail` (extended) or Sidebar |
| **Player** | `MiniPlayer` (Bottom, above Nav) | `PlayerBar` (Bottom, Full Width) | `PlayerBar` (Bottom, Full Width) |
| **Detail** | Full Screen Pushed | Full Screen or Split (if specifically enabled) | Split View or Master-Detail |

### 3. Safe Areas & Insets
- **Mobile**:
  - Top: Transparent status bar. content requests listeners to `MediaQuery.padding.top`.
  - Bottom: `BottomNavigationBar` must respect `MediaQuery.padding.bottom` (Home indicator).
- **Desktop**:
  - Window Title Bar: Custom embedded traffic lights (macOS). Title bar area is reserved.

---

## UI Constraints / Open Questions

1.  **Image Caching Performance**:
    - *Constraint*: UI expects `artworkUri` to be resolveable by standard `NetworkImage` or `FileImage`.
    - *Question*: For huge lists, we need a resize service. Does the Backend `MediaFileAccess` provide a parameter `?size=200`? **Design Assumption**: Yes, generic image provider handles resizing.

2.  **Web File Handles**:
    - *Constraint*: On Web, `artworkUri` might be a blob URL that expires.
    - *Mitigation*: UI Controllers must handle rebuilding these URLs on session restore.

3.  **List Virtualization**:
    - *Constraint*: Library might have 50,000 tracks.
    - *Decision*: All library views use `CustomScrollView` + `SliverList` / `SliverGrid`.

4.  **No "Backend" Logic in UI**:
    - Playback progress interpolation happens in the UI layer (Widget `Ticker`) driven by the sync signal from the controller, to avoid 60fps bridge updates.

