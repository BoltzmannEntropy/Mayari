# Mayari v1.0.0 Release Notes

**Release Date:** February 2026

## Overview

Mayari v1.0.0 is the initial release of the academic PDF reader with quote extraction and text-to-speech capabilities. Named after the Philippine goddess of the moon, Mayari provides researchers with a focused reading and annotation environment.

## Features

### PDF Reading
- **Two-Pane Layout**: PDF viewer on the left, quote library on the right
- **Page Navigation**: Smooth scrolling with page number display
- **Zoom Controls**: Adjust document zoom for comfortable reading
- **PDF Library**: Browse and organize your research documents

### Quote Extraction
- **One-Key Capture**: Select text and press Cmd+D to capture quotes
- **Highlight Mode**: Toggle to auto-capture every text selection
- **Page Tracking**: Automatic page number attribution
- **Quote Management**: Edit, delete, and organize captured quotes

### Citation Management
- **Metadata Entry**: Enter book/paper details once
- **APA Formatting**: Automatic citation generation
- **Multi-source Support**: Track quotes from multiple documents
- **Export Ready**: Properly formatted for academic writing

### Text-to-Speech
- **Kokoro TTS**: High-quality British voice synthesis
- **8 Voice Options**: Choose from multiple British accents
- **Listen While Working**: Audio playback during research
- **Document Reading**: Read entire pages or selected text

### Export
- **Markdown Export**: One-click export with formatted citations
- **Quote Collections**: Export quotes grouped by source
- **Copy to Clipboard**: Quick copy for individual quotes

## Technical Details

- **Version**: 1.0.0 (build 1)
- **Platform**: macOS (Apple Silicon and Intel)
- **Framework**: Flutter 3.x
- **TTS Backend**: Kokoro (Python)
- **Minimum macOS**: 12.0 (Monterey)

## Installation

1. Download `Mayari-1.0.0.dmg`
2. Open the DMG and drag Mayari to Applications
3. Copy the Backend folder to `~/Library/Application Support/Mayari/`
4. On first launch, right-click the app and select "Open" (macOS Gatekeeper bypass)

## First-time Setup

```bash
# Install TTS backend (optional, for text-to-speech)
mayarictl install
mayarictl tts start

# Launch the app
open /Applications/Mayari.app
```

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| macOS | 12.0 | 13.0+ |
| RAM | 8GB | 16GB |
| Storage | 500MB app + 350MB models | 2GB |
| CPU | Any | Apple Silicon |

## Checksums

SHA256 checksums should be verified after download.

## Known Issues

- First launch requires Gatekeeper bypass (right-click > Open)
- TTS models download on first use (~350MB)
- Some PDF formats may have text extraction limitations

## License

- Source code: Business Source License 1.1 (`LICENSE`)
- Binary distribution: Binary Distribution License (`BINARY-LICENSE.txt`)
- License overview: `LICENSE.md`

---

**Website:** https://qneura.ai/apps.html

For bug reports and feature requests, visit the GitHub repository or contact: solomon@qneura.ai
