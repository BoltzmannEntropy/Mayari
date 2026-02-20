# Mayari v1.0.1 Release Notes

**Release Date:** February 20, 2026

## Highlights

- Added Mimika-style in-document PDF read-aloud highlighting with live word tracking.
- Unified text processing to fix glued-word sentence parsing in read-aloud previews.
- Replaced modal audiobook creation with a persistent **Jobs queue** in the left sidebar.
- Added retry/cancel/remove controls for audiobook jobs.
- Added safety checks to mark empty/inaudible audiobook output as failed (with explicit error details).
- Updated app and website screenshots to the latest reader UI.

## Audiobook Workflow Changes

- `Create Audiobook` now enqueues background jobs immediately instead of opening a popup.
- Jobs are visible in the left deck under `Jobs`.
- Queue processing is sequential and persisted locally across app restarts.
- Failed jobs now show underlying errors (for example model-load race or empty output).

## Native TTS and Stability

- Improved native model-load handling to wait when load is already in progress.
- Added stricter output validation for generated audiobook files.

## Distribution

- **Version:** `1.0.1+2`
- **Primary Artifact:** `Mayari-1.0.1.dmg`
- **Platform:** macOS 15.0+ (Apple Silicon)

## Screenshot

Latest UI preview:

https://boltzmannentropy.github.io/mayari-web/images/mayari-reader-2026-02-20-web.png

