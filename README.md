<div align="center">
  <h1>Mayari</h1>
  <p><i>PDF quote extraction and read-aloud workspace for academic research</i></p>
  <p>
    <a href="https://boltzmannentropy.github.io/mayari-web/"><strong>Website</strong></a>
    ·
    <a href="https://github.com/BoltzmannEntropy/Mayari"><strong>GitHub</strong></a>
  </p>
</div>

Mayari is a desktop app for collecting, organizing, and exporting quotes from research PDFs. It combines a PDF reader, quote manager, optional text-to-speech, and a markdown text reader in one workspace.

License: source code is under BSL-1.1. Binary distributions use the Mayari Binary Distribution License. See `LICENSE`, `BINARY-LICENSE.txt`, and `LICENSE.md`.

## Screenshot

![Mayari Screenshot](https://boltzmannentropy.github.io/mayari-web/images/mayari-screenshot.png)

## Current Feature Set

| Area | What it does now |
| --- | --- |
| PDF workspace | Three-pane layout: library sidebar, PDF/Text content pane, and quotes panel |
| PDF library | Open a folder of PDFs, pick files, or drag-and-drop PDFs/folders |
| Source metadata | Prompts for title, author, year, optional publisher when opening a new PDF |
| Quote capture | Select text and save as quote with page number (`Cmd/Ctrl + D`) |
| Highlight mode | Auto-captures selected text while enabled (`Cmd/Ctrl + H`) |
| Quote management | Edit, delete, and reorder quotes per source |
| Export | Copy all quotes to clipboard or export to `.md` |
| Text reader mode | Toggle from PDF to Text mode; edit/view markdown and read it aloud |
| TTS (optional) | Kokoro-based speech with voice selection, speed control, play/pause/stop/skip |
| Diagnostics | Collapsible system logs panel with clear/export actions |

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd/Ctrl + D` | Add selected PDF text as quote |
| `Cmd/Ctrl + H` | Toggle highlight mode |
| `Space` | Play/Pause TTS in active content pane |
| `Escape` | Stop TTS |
| `Cmd/Ctrl + E` | Toggle edit/view mode in Text Reader |

## Quick Start (Development)

### Prerequisites

- Flutter 3.x with macOS desktop enabled
- Python 3.10+
- macOS (the app can compile cross-platform, but current packaged binaries are macOS-only)

### Setup

```bash
git clone https://github.com/BoltzmannEntropy/Mayari.git
cd Mayari
./install.sh
```

`./install.sh` creates the backend virtualenv, installs Python requirements, and runs `flutter pub get`.

### Run the app

```bash
flutter run -d macos
```

## Optional Service Runner (`mayarictl`)

The helper script at `bin/mayarictl` can run backend + app together.

```bash
# Start backend + Flutter
./bin/mayarictl up --dev

# Check status
./bin/mayarictl status

# Stop everything
./bin/mayarictl down
```

## TTS Notes

- TTS uses a local backend on `127.0.0.1:8787` by default.
- In packaged macOS builds with bundled backend resources, Mayari attempts to auto-start the backend.
- In development (`flutter run`), run the backend manually if needed:

```bash
cd backend
source .venv/bin/activate
python main.py
```

- Available built-in British voices include:
  - Female: `bf_emma`, `bf_isabella`, `bf_alice`, `bf_lily`
  - Male: `bm_george`, `bm_fable`, `bm_lewis`, `bm_daniel`

## Export Format

Quotes export as markdown grouped by source citation, for example:

```markdown
# Collected Quotes

## "Book Title" by Author Name (2020).

> "Quote text"
>
> — p. 42
```

## Data and Storage

- Quotes/sources and TTS preferences are saved in a single JSON file named `mayari_data.json` in the app documents directory.
- Exported diagnostic logs are also written to the app documents directory.
- Generated backend audio files are stored under the backend runtime output directory.

## Useful Environment Variables

- `MAYARI_DEFAULT_PDF_LIBRARY`: preselect a default PDF folder on launch
- `MAYARI_BACKEND_HOST`: backend host (default `127.0.0.1`)
- `MAYARI_BACKEND_PORT`: backend port (default `8787`)
- `MAYARI_ALLOW_ORIGINS`: comma-separated CORS origins for backend

## Project Layout

```text
lib/         Flutter app (UI, state, services)
backend/     FastAPI backend for TTS + PDF text extraction
bin/         Local control scripts (mayarictl)
scripts/     Build/release helper scripts
macos/       macOS runner and resources
```

## Limitations

- Quote capture depends on selectable PDF text (scanned PDFs need OCR outside the app).
- Citation output is a simple source string, not full citation-style formatting.
- TTS requires local backend availability.

## License

- Source code: Business Source License 1.1 (`LICENSE`)
- Binary distribution: Mayari Binary Distribution License (`BINARY-LICENSE.txt`)
- Overview: `LICENSE.md`
- Website license page: https://boltzmannentropy.github.io/mayari-web/license.html
