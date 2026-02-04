# Phase 5 Codex Support Notes

## Settings Infrastructure
- Settings persisted via `shared_preferences`.
- Defaults defined in `AppSettings.defaults()`.
- Lightweight migration support via `version` field.

## Capability Flags
- `supportsGapless` and `supportsPlaybackSpeed` are false until implemented.
- Desktop tray support is flagged for desktop platforms only.

## Known Limitations
- Playback speed and gapless settings are stored but not applied to playback yet.

