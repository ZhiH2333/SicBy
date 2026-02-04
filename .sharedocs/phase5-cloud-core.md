# Phase 5.1 Cloud-Aware Playback Notes

## Behavior Summary
- Cloud-only tracks trigger a download workflow on play.
- Current track is not updated until download completes.
- Download progress and failure reasons are exposed via playback state.

## Platform Limitations
- No real cloud provider integration yet; downloads are simulated in-memory.
- Web memory constraints may limit large file download simulations.

