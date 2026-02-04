# SicBy Phase 3 Implementation Planning & Scaffolding

## Scope
- Design-only scaffolding and planning.
- No business logic, no UI work, no database queries, no playback implementation.

## Folder & Package Structure (Proposed)
- `lib/domain/`
- `lib/application/`
- `lib/services/`
- `lib/platform/`
- `lib/shared/`

## Ownership & TODO Conventions
- Use tags in TODOs to mark ownership:
- `[CodeX]` Core architecture and service boundary TODOs.
- `[Copilot]` Feature implementation TODOs.
- `[Shared]` Cross-cutting or collaborative TODOs.

## Phase 3 Roadmap
### Phase 3.1 Minimal Vertical Slice (scan → index → play)
- [CodeX] Define library scan workflow contracts and event flow.
- [Copilot] Implement minimal file discovery and raw tag extraction.
- [Shared] Wire ingestion → local index → playback queue at a conceptual level.
- [CodeX] Establish basic test harness boundaries (no real tests yet).

### Phase 3.2 Metadata & Lyrics
- [CodeX] Define metadata normalization and provenance handling pipeline.
- [Copilot] Implement local metadata providers (embedded tags, sidecar files).
- [Shared] Add enrichment scheduling and reprocessing flow.

### Phase 3.3 Persistence & Playlists
- [CodeX] Define LocalDatabaseService schema boundaries and migrations plan.
- [Copilot] Implement persistence CRUD for core entities.
- [Shared] Introduce playlists and play history persistence.

### Phase 3.4 Platform Hardening
- [CodeX] Define platform capability matrix and fallback behavior.
- [Copilot] Implement platform services and error mapping.
- [Shared] Add resilience for limited web filesystem capability.

## Implementation Order (Suggested)
1. Domain entities and shared types.
1. Service interfaces and error contracts.
1. Application controllers and event flow wiring.
1. Platform adapters (minimal stubs only).
1. Incremental expansion by milestone.

## Parallel Work Guardrails
- UI must call controllers only (never services or platform APIs directly).
- Services must not import UI modules.
- Platform implementations must stay behind interface boundaries.

## Cross-Platform Risks
- Web filesystem access persistence (File System Access API vs session-only uploads).
- Mobile storage scope variability (user-picked folders only vs broad access).
- Background execution limits (scan scheduling, playback stability).
- Audio backend feature gaps (gapless/crossfade not guaranteed).

## Repository Readiness Checklist
- Scaffold core folders.
- Add placeholder README files with TODOs.
- Keep UI code untouched.
