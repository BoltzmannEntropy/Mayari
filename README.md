<div align="center">
  <h1>Mayari</h1>
  <p><i>PDF quote extraction and read-aloud workspace for academic research</i></p>
  <p>
    <a href="https://boltzmannentropy.github.io/mayari-web/"><strong>Website</strong></a>
    ·
    <a href="https://github.com/BoltzmannEntropy/Mayari"><strong>GitHub</strong></a>
  </p>
</div>

Mayari is a desktop app for collecting, organizing, and exporting quotes from research PDFs. It combines a PDF reader, quote manager, native text-to-speech, and a markdown text reader in one workspace.

**100% Native** — No Python, no backend servers. TTS runs natively on Apple Silicon using the MLX framework via KokoroSwift.

License: source code is under BSL-1.1. Binary distributions use the Mayari Binary Distribution License. See `LICENSE`, `BINARY-LICENSE.txt`, and `LICENSE.md`.

## Screenshot

![Mayari Screenshot](https://boltzmannentropy.github.io/mayari-web/images/mayari-screenshot.png)

## Current Feature Set

| Area | What it does now |
| --- | --- |
| PDF workspace | Three-pane layout: library sidebar, PDF/Text content pane, and quotes panel |
| PDF library | Open a folder of PDFs, pick files, or drag-and-drop PDFs/folders |
| Source metadata | Prompts for title, author, year, optional publisher when opening a new PDF |
| Quote capture | Select text and save as quote with page number (`Cmd + D`) |
| Highlight mode | Auto-captures selected text while enabled (`Cmd + H`) |
| Quote management | Edit, delete, and reorder quotes per source |
| Export | Copy all quotes to clipboard or export to `.md` |
| Text reader mode | Toggle from PDF to Text mode; edit/view markdown and read it aloud |
| TTS (native) | Kokoro TTS with British voices, speed control, play/pause/stop — no Python required |
| Diagnostics | Collapsible system logs panel with clear/export actions |

## System Requirements

- **macOS 15.0+** (Sequoia) — required for Apple MLX framework
- **Apple Silicon** (M1/M2/M3/M4) — MLX runs on Apple GPU

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd + D` | Add selected PDF text as quote |
| `Cmd + H` | Toggle highlight mode |
| `Space` | Play/Pause TTS in active content pane |
| `Escape` | Stop TTS |
| `Cmd + E` | Toggle edit/view mode in Text Reader |

## Quick Start (Development)

### Prerequisites

- Flutter 3.x with macOS desktop enabled
- Xcode 16+ (for macOS 15 SDK and Swift Package Manager)
- macOS 15.0+ on Apple Silicon

### Setup

```bash
git clone https://github.com/BoltzmannEntropy/Mayari.git
cd Mayari
flutter pub get
```

### Run the app

```bash
flutter run -d macos
```

On first run, you'll be prompted to download the Kokoro TTS model (~340MB). This is a one-time download stored in the app's Application Support folder.

## Text-to-Speech

Mayari uses **KokoroSwift**, a native Swift implementation of the Kokoro TTS model running on Apple's MLX framework. This provides:

- **Offline operation** — no internet required after model download
- **Fast generation** — 3-5x faster than real-time on Apple Silicon
- **Low memory** — ~320MB RAM usage during synthesis
- **High quality** — neural TTS with natural prosody

### Available Voices

All voices are British English:

| Voice | Name | Gender | Quality |
| --- | --- | --- | --- |
| `bf_emma` | Emma | Female | B- (default) |
| `bf_isabella` | Isabella | Female | C |
| `bf_alice` | Alice | Female | D |
| `bf_lily` | Lily | Female | D |
| `bm_george` | George | Male | C |
| `bm_fable` | Fable | Male | C |
| `bm_lewis` | Lewis | Male | D+ |
| `bm_daniel` | Daniel | Male | D |

### Model Files

The TTS model is downloaded on first use:

- **kokoro-v1_0.safetensors** (~327MB) — the neural network weights
- **voices.npz** (~14MB) — voice embeddings for all available voices

Files are stored in:
```
~/Library/Containers/com.mayari.mayariTemp/Data/Library/Application Support/Mayari/kokoro-model/
```

## Export Format

Quotes export as markdown grouped by source citation:

```markdown
# Collected Quotes

## "Book Title" by Author Name (2020).

> "Quote text"
>
> — p. 42
```

## Data and Storage

- Quotes/sources and TTS preferences are saved in `mayari_data.json` in the app documents directory
- Exported diagnostic logs are written to the app documents directory
- TTS model files are stored in Application Support (see above)

## Project Layout

```text
lib/         Flutter app (UI, state, services)
macos/       macOS runner, native plugins, Swift Package Manager dependencies
scripts/     Build/release helper scripts
```

### Native TTS Plugin

The TTS implementation is in `macos/Runner/KokoroTTSPlugin.swift`, which:

- Loads the Kokoro model via KokoroSwift
- Handles voice embedding loading from NPZ files
- Generates audio using MLX on the Apple GPU
- Plays audio via AVAudioPlayer

## Building a Release

```bash
# Build release app
flutter build macos --release

# Create DMG (if build-dmg.sh exists)
./scripts/build-dmg.sh
```

## Limitations

- Quote capture depends on selectable PDF text (scanned PDFs need OCR outside the app)
- Citation output is a simple source string, not full citation-style formatting
- TTS requires macOS 15.0+ and Apple Silicon

## License

- Source code: Business Source License 1.1 (`LICENSE`)
- Binary distribution: Mayari Binary Distribution License (`BINARY-LICENSE.txt`)
- Overview: `LICENSE.md`
- Website license page: https://boltzmannentropy.github.io/mayari-web/license.html
