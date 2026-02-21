# Mayari v1.0.3 Release Notes

**Release Date:** February 21, 2026

## Highlights

- Website now features audio demos showcasing all 8 British TTS voices
- Hero section includes sample audio player for quick voice preview
- Voice Samples section with playable demos for Emma, Isabella, Alice, Lily, George, Fable, Lewis, and Daniel

## Previous Release (v1.0.2)

- Added explicit `Play`, `Pause`, and `Stop` controls on each audiobook card.
- Kept queue-based audiobook generation with jobs in the left sidebar (`Jobs` tab).
- Added model file location visibility in Settings (`Text-to-Speech` > `Model location`).
- Removed hardcoded external-volume PDF defaults that triggered removable-volume access issues.
- Added readable-file checks so inaccessible/stale PDF paths are filtered out safely.
- Improved extraction error messages for denied file access.

## Audiobook Workflow

- `Create Audiobook` enqueues background jobs immediately.
- Jobs are processed sequentially and persisted across restarts.
- Failed jobs expose detailed error messages and can be retried/cancelled.

## Stability

- Startup no longer depends on hardcoded `/Volumes/...` paths.
- Saved sources that are no longer readable are auto-pruned.

## Distribution

- **Version:** `1.0.3+4`
- **Primary Artifact:** `Mayari-1.0.3.dmg`
- **Platform:** macOS 15.0+ (Apple Silicon)
