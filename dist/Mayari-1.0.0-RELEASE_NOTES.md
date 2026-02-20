# Mayari v1.0.0 Release Notes

**Release Date:** February 2026

## Overview

Mayari v1.0.0 is the initial release of the academic PDF reader with quote extraction and native text-to-speech. Named after the Philippine goddess of the moon, Mayari provides researchers with a focused reading and annotation environment.

**100% Native** — No Python, no backend servers. TTS runs natively on Apple Silicon using the MLX framework via KokoroSwift.

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

### Text-to-Speech (Native)
- **KokoroSwift TTS**: High-quality British voice synthesis using Apple MLX
- **8 Voice Options**: Choose from multiple British accents
- **Offline Operation**: No internet required after model download
- **Fast Generation**: 3-5x faster than real-time on Apple Silicon

### Export
- **Markdown Export**: One-click export with formatted citations
- **Quote Collections**: Export quotes grouped by source
- **Copy to Clipboard**: Quick copy for individual quotes

## Technical Details

- **Version**: 1.0.0 (build 1)
- **Platform**: macOS 15.0+ (Apple Silicon)
- **Framework**: Flutter 3.x
- **TTS Engine**: KokoroSwift (Native Swift/MLX)
- **Minimum macOS**: 15.0 (Sequoia)

## Installation

1. Download `Mayari-1.0.0.dmg`
2. Open the DMG and drag Mayari to Applications
3. On first launch, right-click the app and select "Open" (macOS Gatekeeper bypass)
4. TTS model (~340MB) downloads automatically on first use

## System Requirements

| Component | Requirement |
|-----------|-------------|
| macOS | 15.0+ (Sequoia) |
| CPU | Apple Silicon (M1/M2/M3/M4) |
| RAM | 8GB minimum |
| Storage | ~400MB (app + TTS model) |

## Checksums

SHA256 checksums should be verified after download.

## Known Issues

- First launch requires Gatekeeper bypass (right-click > Open)
- TTS models download on first use (~340MB)
- Some PDF formats may have text extraction limitations
- Requires macOS 15.0+ and Apple Silicon for TTS

## License

- Source code: Business Source License 1.1 (`LICENSE`)
- Binary distribution: Binary Distribution License (`BINARY-LICENSE.txt`)
- License overview: `LICENSE.md`

---

**Website:** https://qneura.ai/apps.html

For bug reports and feature requests, visit the GitHub repository or contact: solomon@qneura.ai
