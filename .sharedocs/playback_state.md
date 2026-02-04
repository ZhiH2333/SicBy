# Playback State Machine (Phase 5.1)

## States
- Idle
- PendingDownload
- Ready
- Playing
- Paused

## Transition Rules
- Idle -> Ready (local track selected, preflight ok)
- Idle -> PendingDownload (cloud-only selected)
- Ready -> Playing (playback started)
- Ready -> Idle (stop or failure)
- Playing -> Paused (pause or playback stream stops)
- Playing -> Ready (explicit track change)
- Playing -> Idle (stop)
- Paused -> Playing (resume)
- Paused -> Ready (explicit track change)
- Paused -> Idle (stop)
- PendingDownload -> Ready (download completed)
- PendingDownload -> Idle (download failed or canceled)

## Invariants
- `currentTrack` is only updated when transition -> Playing succeeds.
- `selectedTrack` can be set on click, `pendingTrack` is set while loading/downloading.
- Cloud-only selections never mutate `currentTrack` until download completes.
- Next/Previous are blocked while `PendingDownload` when setting `disableSwitchDuringDownload` is true.
