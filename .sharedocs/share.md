## Module List
1. Core Domain
2. Application Controllers
3. Library Ingestion
4. Metadata & Lyrics Enrichment
5. Playback
6. Local Index & Database
7. Platform Abstractions
8. Import/Export (Offline)

## Interface Responsibilities
1. Core Domain
Defines pure domain entities, value objects, and invariant rules. No IO, no platform knowledge.

1. Application Controllers
Orchestrate workflows and coordinate services. Expose high-level, async-capable operations for UI consumption without exposing platform APIs. Includes LibraryController, PlaybackController, MetadataController.

1. Library Ingestion
Discovers local media sources and extracts file-level metadata. Emits domain events for indexing and enrichment. No persistence or UI responsibilities.

1. Metadata & Lyrics Enrichment
Normalizes metadata, merges sources, and produces canonical profiles with provenance and confidence. Operates offline using embedded tags, sidecars, cached lookups, and user edits.

1. Playback
Provides queue, playback state, and control operations. Delegates actual audio output to platform audio backends through AudioPlaybackService.

1. Local Index & Database
Persists library catalog, scan history, derived metadata, user edits, and play history. Provides query and search interfaces.

1. Platform Abstractions
Provides platform-specific capabilities behind stable interfaces: filesystem access, audio session, permissions, background execution, and paths.

1. Import/Export (Offline)
Supports user-initiated import/export of metadata, playlists, and scan data. Offline-only.

## Data Contracts (conceptual, no code)
1. Domain Models
Track
- Identifiers: trackId, sourceId (file-level), canonicalId
- File: mediaLocator, fileHash, fileSize, containerType, codec, bitrate, sampleRate, channels, duration
- Tags: title, albumTitle, artistName, albumArtistName, trackNumber, discNumber, year, genre, composer, bpm, lyrics
- Artwork: embeddedArtworkRef, artworkCacheRef
- Dates: addedAt, lastScannedAt, lastPlayedAt
- Flags: isCorrupt, isMissing, isExplicit, isUserEdited
- Provenance: tagSourcePriority, confidenceScore

Album
- Identifiers: albumId, canonicalId
- Core: title, albumArtist, year, genre, totalTracks, totalDiscs
- Artwork: artworkCacheRef
- Stats: durationTotal, trackCount
- Provenance: confidenceScore, sourceRefs

Artist
- Identifiers: artistId, canonicalId
- Core: name, sortName
- Stats: albumCount, trackCount, durationTotal
- Artwork: artworkCacheRef

Playlist
- Identifiers: playlistId
- Core: name, description, createdAt, updatedAt
- Items: orderedTrackRefs (with optional range or position metadata)
- Flags: isUserEditable, isSmartPlaylist

LibraryLocation
- Identifiers: locationId
- Core: label, mediaLocatorRoot, accessType, platformScope
- State: lastScanStatus, lastScanAt

ScanJob
- Identifiers: scanId
- Core: startedAt, completedAt, scope, mode (full/incremental), status, errorSummary
- Stats: filesScanned, tracksAdded, tracksUpdated, tracksRemoved

PlaybackState
- Core: status (stopped/playing/paused/buffering), position, bufferedPosition, duration
- Queue: currentTrackRef, nextTrackRef, previousTrackRef, repeatMode, shuffleMode
- Output: volume, outputDeviceId, sessionState

MetadataProfile
- Core: normalized fields for display (title, album, artist, albumArtist, year, genre)
- Confidence: per-field confidence
- Provenance: per-field source list (embedded, sidecar, cache, user)

MediaLocator
- Core: locatorType (path, handle, uri), locatorValue, accessToken/handleRef
- Capabilities: randomAccess, streamable, persistentAcrossSessions

2. Application Controllers
LibraryController
- Initiates scans, cancels scans, reads scan status.
- Fetches library summaries and search results.
- Provides library update events for UI (via event stream or observer).

PlaybackController
- Controls play, pause, seek, skip, queue operations.
- Exposes playback state stream.
- Manages repeat/shuffle and playback preferences.

MetadataController
- Triggers enrichment and reprocessing tasks.
- Applies user edits and manages overrides.
- Exposes metadata confidence and provenance to other modules.

3. Service-Layer Interfaces
FileSystemService
- Enumerate locations, list files by pattern, open read streams, compute hashes.
- Capability queries: canScanFolders, canPersistHandles, canReadMetadata.
- Access errors: permissionDenied, notFound, unsupported.

AudioPlaybackService
- Load media by MediaLocator.
- Play, pause, seek, stop, setVolume.
- Emit playback state and completion events.
- Report output capabilities (gapless, crossfade, background).

MetadataProviderService
- Parse embedded tags and audio headers.
- Parse sidecar metadata or lyric files.
- Provide normalized metadata and confidence.

LocalDatabaseService
- CRUD for domain entities.
- Query interfaces for search and filtering.
- Transaction boundaries and migrations.
- Events for data changes.

4. Platform Abstraction Interfaces
AudioSessionService
- Manage focus, interruptions, route changes.
- Report session state changes.

PermissionsService
- Request and check filesystem access.
- Report permission scopes (single folder, broad storage).

BackgroundExecutionService
- Report capability for background scanning/playback.
- Schedule or cancel background tasks (best-effort).

PathProviderService
- Provide cache, data, and temp paths.

## Data Flow Summary
1. UI calls LibraryController.scan() (async) with a LibraryLocation reference.
1. LibraryController invokes FileSystemService to enumerate files and MetadataProviderService to extract raw tags.
1. Ingestion emits TrackDiscovered/TrackUpdated events to LocalDatabaseService.
1. MetadataController subscribes to ingestion events, performs normalization and enrichment, and writes MetadataProfiles to LocalDatabaseService.
1. PlaybackController resolves Track -> MediaLocator via LocalDatabaseService, then instructs AudioPlaybackService to load/play.
1. AudioPlaybackService emits PlaybackState updates to PlaybackController, which forwards to UI.
1. Import/Export operates through LocalDatabaseService and FileSystemService only, no direct UI file access.

## Risks / Open Questions
1. Web filesystem access
Need decision on File System Access API vs session-only uploads to finalize MediaLocator persistence guarantees.

1. Mobile storage scope
If access is limited to user-picked folders, re-scan flows and cache invalidation must be explicit.

1. Gapless and crossfade
Whether required in Phase 2 influences AudioPlaybackService capabilities and buffering contracts.

1. User edit precedence
Define a consistent rule for override precedence vs embedded tags to avoid metadata oscillation.

1. Large library performance
Indexing and artwork caching policies need constraints (expected library size, device class).

1. Background constraints
Platform policies for background scanning/playback vary; clarify minimum viable behavior per platform.

---
# Part 2: UI/UX Design Strategy (Copilot)

## Proposal: UI layout system & navigation model

### 1. Architecture & State Management
- **Pattern**: MVVM-style using `Riverpod` for state management.
    - **View**: Flutter Widgets (dumb, state-driven).
    - **ViewModel (Controller)**: `StateNotifier` / `Notifier` holding independent state (e.g., `LibraryController`, `PlaybackController`).
    - **Repository**: Interfaces defined by CodeX (e.g., `AudioBackend`, `LibraryIndex`).
- **Navigation**: `GoRouter` for deep linking and declarative routing.
    - Supports nested navigation for "Shell" layouts (persistent player bar).
    - **Routes**:
        - `/` (Home)
        - `/search`
        - `/library`
        - `/album/:id`
        - `/artist/:id`
        - `/settings`

### 2. Adaptive Navigation Layout
- **Mobile (< 600dp)**:
    - **Bottom Navigation Bar**: [Home, Search, Library].
    - **Now Playing**: Mini-player docked above Bottom Nav. Tap to expand to full screen.
- **Tablet/Desktop (> 600dp)**:
    - **Navigation Rail / Sidebar**: Left-aligned.
    - **Now Playing**: Persistent footer bar full width (classic desktop player feel).
    - **Master-Detail**: Library view uses split panes on large screens.

### 3. Screen Structure
- **Root Shell**: Handles the Navigation adapter (Rail vs Bottom) and the Overlay Player.
- **Library**:
    - **Tabs**: Playlists | Artists | Albums.
    - **Content**: Virtualized Grids/Lists (`SliverGrid`, `SliverList`) for memory efficiency with large libraries.
- **Now Playing**:
    - **Visuals**: Large prominent artwork, blurred backdrop/gradient.
    - **Lyrics**: Synced lyrics view overlay or side-panel (desktop).

## Decisions: Design system choices

### 1. Visual Language ("Pulse" Theme)
- **Philosophy**: "Dark, deeply immersive, data-forward."
- **Color Palette**:
    - **Surface**: `#121212` (Spotify Black) or `#09090b` (Deep Zinc).
    - **Accent**: `Electric Teal` (`#00F0A8`) for primary actions.
    - **Text**: Pure White (`#FFFFFF`) for headers, Light Grey (`#B3B3B3`) for metadata.
- **Typography**:
    - **Font**: `Inter` (clean, Swiss-style sans serif) or System defaults if bold enough.
    - **Hierarchy**: Heavy/Black weights for headers, tabular numbers for durations.

### 2. Motion & Interaction
- **Micro-interactions**: Scale-down on click for list items.
- **Transitions**:
    - **Fade Through**: For switching main tabs.
    - **Shared Element**: Album cover floats from grid to Detail view.
- **Feedback**: Immediate local updates. Optimistic UI for "Heart" / "Queue" actions.

## Open Questions: Dependencies on backend or unclear flows

1. **Cover Art Delivery**:
    - Will the `MediaFileAccess` provide a specific endpoint/stream for resized thumbnails? Decoding 50MB FLAC headers for thumbs on the UI thread will stutter. *Assumption: Backend provides a cached image provider/path.*
2. **Infinite Scroll / Pagination**:
    - For libraries with 10k+ tracks, does the `Local Index` support range-based paging? UI will need this.
3. **Waveforms**:
    - If we want a waveform in the player, does the `scan` process extract amplitude data? (Low priority).
4. **Android/iOS Safe Areas**:
    - Need to ensure the `PlaybackService` handles `safeArea` insets for edge-to-edge content (transparent status bars).

---
> **[Update] Phase 2: UI/UX Contracts**
> Detailed UI Module Interface Definitions are located in: [copilot-ui-contracts.md](./copilot-ui-contracts.md)
