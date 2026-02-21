# Mayari v1.0.5 Release Notes

**Release Date:** February 21, 2026

## Highlights

- Added long-form audiobook generation flow from public-domain history text.
- Added reproducible long-text test runner with British Kokoro voices.
- Synchronized website demo audio samples into app assets for exact sample parity between code and website.
- Website now includes multilingual language demo cards with generated sample audio.

## Long-Form Audiobooks

- Added bundled public-domain source text:
  - `assets/examples/texts/public_domain_history_wells_excerpt.txt`
- Added long audiobook runner:
  - `tool/long_history_audiobook_runner.dart`
  - `scripts/generate-long-history-audiobooks.sh`
- Generated long audiobook examples in app assets:
  - `long_history_bf_emma_*.wav`
  - `long_history_bm_george_*.wav`
  - `long_history_manifest_*.json`

## Audio Sample Sync

- Mirrored all website `sample-*.mp3` demos into:
  - `assets/examples/audiobooks/`
- Verified hash parity between `MayariWEB/audio` and `MayariCODE/assets/examples/audiobooks`.

## Validation

- Full Flutter test suite passes.
- `dart analyze` passes on modified long-audiobook files.
- macOS debug/release builds complete.
- Long-form generation completed successfully for British voices.

## Distribution

- **Version:** `1.0.5+6`
- **Primary Artifact:** `Mayari-1.0.5.dmg`
- **Platform:** macOS 15.0+ (Apple Silicon)
