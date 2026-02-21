# Mayari v1.0.4 Release Notes

**Release Date:** February 21, 2026

## Highlights

- Added EPUB and DOCX read-aloud support alongside PDF.
- Added bundled Examples with ready-made sample documents and audiobooks for PDF, DOCX, and EPUB.
- Added voice cards and language cards with language-based voice filtering.
- Added repository demo video (`assets/mayari-video.mov`) and replaced the MayariWEB hero image with the demo video.

## Read-Aloud and Audiobooks

- Unified extraction pipeline now supports `.pdf`, `.docx`, and `.epub`.
- Audiobook creation is available for extracted text across supported document formats.
- Included non-placeholder example audiobook WAV files for all three sample formats.

## Voice UX

- Voice cards now expose language metadata in the UI.
- Language cards allow selecting one or multiple languages to filter visible voices.
- Added queue test action to pre-generate language test audiobook jobs.

## Validation

- `dart analyze` reports no issues.
- Full Flutter test suite passes.
- Service tests validate document extraction (PDF/DOCX/EPUB), examples loading, and voice catalog behavior.
- macOS debug and release builds complete successfully.

## Distribution

- **Version:** `1.0.4+5`
- **Primary Artifact:** `Mayari-1.0.4.dmg`
- **Platform:** macOS 15.0+ (Apple Silicon)
