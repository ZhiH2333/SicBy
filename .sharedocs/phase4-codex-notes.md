# Phase 4 Codex Notes

## Web File Access
- Web uses manual file selection via FilePicker with in-memory bytes.
- Folder selection is unavailable on web; UI should label the source as "Selected files".

## Deterministic Track Identity
- Native: Track ID uses full file path (deterministic for a given folder).
- Web: Track ID uses "name|size" due to lack of stable path; collisions are possible.

## Playback on Web
- Playback uses data URIs generated from bytes; large files may be memory-heavy.

