<div align="center">
  <br><br>
  <h1>🌙 Mayari</h1>
  <p><i>A moonlit companion for academic research</i></p>
  <br>
  <code>macOS Only</code>&nbsp;&nbsp;·&nbsp;&nbsp;Flutter Desktop&nbsp;&nbsp;·&nbsp;&nbsp;Kokoro TTS
  <br><br>
  <h2>Read and listen to your PDF books</h2>
  <p>Extract quotes in seconds with automatic citation tracking. Listen with high-quality British TTS.<br>Named after the Philippine goddess of the moon.</p>
  <br>
  <a href="https://boltzmannentropy.github.io/mayari-web/"><strong>Website</strong></a>&nbsp;&nbsp;&nbsp;·&nbsp;&nbsp;&nbsp;<a href="https://github.com/BoltzmannEntropy/Mayari"><strong>View on GitHub</strong></a>
  <br><br>
</div>

> **Read & Listen** | **Quote Extraction** | **Automatic Citations** | **Markdown Export**

A macOS desktop application for **academic researchers**: **read your PDF books** in a clean two-pane interface, **listen with high-quality British TTS** while you work, **extract quotes** with a single keystroke (Cmd+D), and **export to Markdown** with properly formatted citations.

---

## Features at a Glance

| Feature | Description |
|---------|-------------|
| **Quote Extraction** | Select text → Press Cmd+D → Quote captured with page number |
| **Highlight Mode** | Toggle on to auto-capture every text selection |
| **Citation Tracking** | Enter metadata once, every quote gets proper APA citation |
| **Text-to-Speech** | Listen to PDFs with 8 British Kokoro voices |
| **Markdown Export** | One-click export with formatted citations |
| **PDF Library** | Browse and organize your research PDFs |
| **Two-Pane Layout** | PDF viewer left, quotes panel right |

---

## Screenshot

![Mayari Screenshot](assets/mayari-screenshot.png)

### Two-Pane Research Workspace

```
┌─────────────────────────────────────────────────────────────────┐
│  📚 Library  │        PDF Viewer         │    Quote Library     │
│              │                           │                      │
│  📄 Book1.pdf│  ┌───────────────────┐   │  ▼ Apology (Plato)   │
│  📄 Book2.pdf│  │                   │   │    "The only true... │
│  📄 Book3.pdf│  │   Page Content    │   │    "An unexamined... │
│              │  │                   │   │                      │
│              │  │                   │   │  ▼ Republic (Plato)  │
│              │  └───────────────────┘   │    "The measure of...|
│              │                           │                      │
│              │  ◀  Page 42 / 200  ▶     │  [Export Markdown]   │
└─────────────────────────────────────────────────────────────────┘
```

### UI Design

```
┌─────────────────────────────────────────────────────────────────┐
│  Mayari - "Book Title"                                          │
├────────────────────────────────────┬────────────────────────────┤
│  [Zoom -][Zoom +] │ [◀][▶] │ [Highlight Mode]  │    Quotes [+]  │
├────────────────────────────────────┼────────────────────────────┤
│                                    │ ▼ "Book Title" - Author    │
│                                    │   ┌────────────────────┐   │
│                                    │   │ "Quote text..."    │   │
│         PDF VIEWER                 │   │ p. 42  [Edit][Del] │   │
│                                    │   └────────────────────┘   │
│         (60% width)                │   ┌────────────────────┐   │
│                                    │   │ "Another quote..." │   │
│                                    │   │ p. 78  [Edit][Del] │   │
│                                    │   └────────────────────┘   │
│                                    │                            │
│                                    │ ▶ "Another Book" - Author  │
├────────────────────────────────────┼────────────────────────────┤
│         Page 42 of 256             │ 5 quotes from 2 sources    │
│                                    │              [Copy][Export]│
└────────────────────────────────────┴────────────────────────────┘
```

---

## Installation

### System Requirements

| Component | Requirement |
|-----------|-------------|
| **OS** | macOS 12+ (Monterey or later) |
| **CPU** | Apple Silicon (M1/M2/M3/M4) or Intel |
| **RAM** | 8GB minimum |
| **Storage** | 500MB for app, 350MB for TTS models |
| **Flutter** | 3.x with macOS desktop support |
| **Python** | 3.10+ (for TTS backend) |

### Quick Install

```bash
git clone https://github.com/BoltzmannEntropy/Mayari.git
cd Mayari

# Install Flutter dependencies
flutter pub get

# Setup TTS backend (optional, ~350MB download)
./scripts/bundle_kokoro.sh

# Run the app
flutter run -d macos
```

### Manual Setup

```bash
# 1. Clone repository
git clone https://github.com/BoltzmannEntropy/Mayari.git
cd Mayari

# 2. Install Flutter dependencies
flutter pub get

# 3. Setup TTS backend (optional)
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd ..

# 4. Download Kokoro TTS models (optional, ~350MB)
./scripts/bundle_kokoro.sh

# 5. Run the app
flutter run -d macos
```

### Build for Release

```bash
# Build macOS app bundle
flutter build macos --release

# Output: build/macos/Build/Products/Release/Mayari.app

# Create DMG (optional)
./scripts/build-dmg.sh
```

---

## Quick Start

### 1. Open a PDF

- Click **Open PDF** in the toolbar, or
- Drag and drop a PDF onto the viewer, or
- Select from your PDF library sidebar

### 2. Enter Source Metadata

When you open a new PDF, enter the bibliographic information:
- **Title**: Book title
- **Author**: Author name(s)
- **Year**: Publication year
- **Publisher**: (Optional) Publisher name

### 3. Extract Quotes

**Standard Mode:**
1. Select text in the PDF viewer
2. Press **Cmd+D** or click **Add Quote**
3. Quote saved with page number

**Highlight Mode:**
1. Press **Cmd+H** to toggle highlight mode
2. Orange border appears around PDF viewer
3. Every text selection is automatically captured

### 4. Listen to Your PDF (Optional)

1. Click **▶ Play** in the TTS toolbar
2. App extracts text and synthesizes speech
3. Use playback controls: pause, skip, adjust speed
4. Choose from 8 British voices

### 5. Export to Markdown

1. Click **Export** in the quotes panel
2. Save the Markdown file
3. Quotes organized by source with proper citations

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd+D` | Add selected text to quotes |
| `Cmd+H` | Toggle highlight mode |
| `←` / `→` | Previous / next page |
| `Space` | Play / pause TTS |
| `Escape` | Stop TTS |
| `Cmd+O` | Open PDF file |
| `Cmd+E` | Export quotes to Markdown |

---

## Text-to-Speech

Mayari includes optional text-to-speech powered by [Kokoro TTS](https://github.com/hexgrad/kokoro), an open-source neural TTS engine with high-quality British voices.

### Available Voices

| Voice | Gender | Quality |
|-------|--------|---------|
| **Emma** | Female | Best (Recommended) |
| **Isabella** | Female | Good |
| **Alice** | Female | Fair |
| **Lily** | Female | Fair |
| **George** | Male | Good |
| **Fable** | Male | Good |
| **Lewis** | Male | Fair |
| **Daniel** | Male | Fair |

### TTS Controls

| Control | Function |
|---------|----------|
| **Play/Pause** | Start or pause reading |
| **Stop** | Stop and reset to beginning |
| **Skip** | Jump between paragraphs |
| **Speed** | 0.5x to 2.0x playback speed |
| **Voice** | Switch voices on-the-fly |

### TTS Setup

TTS requires a Python backend server running on localhost:8787.

```bash
# Download models and setup (~350MB)
./scripts/bundle_kokoro.sh

# Start the TTS server
cd backend
source .venv/bin/activate
python main.py
```

The app will show server status in the TTS toolbar.

---

## Export Format

Quotes export to Markdown with proper academic formatting:

```markdown
## Apology

Plato (399 BCE). Apology. Athens Press.

> "The only true wisdom is knowing you know nothing." (p. 42)

> "An unexamined life is not worth living." (p. 38)

## Republic

Plato (380 BCE). Republic. Athens Press.

> "The measure of a man is what he does with power." (p. 156)
```

---

## Data Storage

All data is stored locally:

| Data | Location |
|------|----------|
| **Quotes & Sources** | `~/Documents/mayari_data.json` |
| **TTS Settings** | `~/Documents/mayari_data.json` |
| **Generated Audio** | `backend/outputs/` |

Data is auto-saved on every change. No cloud sync, no accounts required.

---

## Architecture

```
Mayari/
├── lib/                              # Flutter app (4,496 lines Dart)
│   ├── main.dart                     # App entry point
│   ├── models/
│   │   ├── source.dart               # PDF source with metadata
│   │   └── quote.dart                # Extracted quote model
│   ├── providers/                    # Riverpod state management
│   │   ├── sources_provider.dart     # Quotes & sources state
│   │   ├── tts_provider.dart         # TTS playback state
│   │   ├── library_provider.dart     # PDF library browsing
│   │   └── pdf_provider.dart         # PDF viewer state
│   ├── screens/
│   │   └── workspace_screen.dart     # Main two-pane layout
│   ├── services/
│   │   ├── storage_service.dart      # JSON persistence
│   │   ├── export_service.dart       # Markdown export
│   │   ├── tts_service.dart          # Kokoro TTS integration
│   │   └── log_service.dart          # Debug logging
│   └── widgets/
│       ├── pdf_viewer/
│       │   └── pdf_viewer_pane.dart  # PDF viewer (898 lines)
│       ├── quotes_panel/
│       │   ├── quotes_panel.dart     # Quotes library
│       │   ├── quote_card.dart       # Individual quote
│       │   └── source_header.dart    # Source grouping
│       ├── tts/
│       │   ├── tts_toolbar.dart      # Playback controls
│       │   └── speaker_cards.dart    # Voice selection
│       ├── library/
│       │   └── library_sidebar.dart  # PDF library browser
│       ├── dialogs/
│       │   ├── source_metadata_dialog.dart
│       │   ├── quote_edit_dialog.dart
│       │   └── settings_dialog.dart
│       └── logs/
│           └── logs_panel.dart       # Debug logs
│
├── backend/                          # Python TTS server
│   ├── main.py                       # FastAPI server (port 8787)
│   ├── requirements.txt              # Python dependencies
│   ├── tts/
│   │   └── kokoro_engine.py          # Kokoro TTS wrapper
│   └── outputs/                      # Generated audio
│
├── scripts/
│   ├── bundle_kokoro.sh              # Download TTS models
│   ├── install.sh                    # Setup script
│   ├── flutter.sh                    # Build helper
│   └── build-dmg.sh                  # macOS DMG builder
│
├── docs/plans/                       # Design documents
├── macos/                            # macOS platform code
└── test/                             # Widget tests
```

---

## Codebase Statistics

| Language | Lines of Code | Files |
|----------|--------------|-------|
| **Dart** (Flutter UI) | ~4,500 | 23 |
| **Python** (TTS backend) | ~400 | 3 |
| **Total** | **~4,900** | **26** |

### Dart Breakdown

| Component | Lines | Description |
|-----------|-------|-------------|
| `widgets/pdf_viewer/` | 898 | PDF viewer with text extraction |
| `widgets/quotes_panel/` | 554 | Quotes library and cards |
| `providers/` | 679 | Riverpod state management |
| `services/` | 416 | Storage, export, TTS services |
| `widgets/tts/` | 519 | TTS controls and voice selection |
| `widgets/library/` | 292 | PDF library sidebar |
| `widgets/logs/` | 251 | Debug logging panel |
| `models/` | 132 | Source and Quote data classes |

### Largest Files

| File | Lines |
|------|-------|
| `widgets/pdf_viewer/pdf_viewer_pane.dart` | 898 |
| `providers/tts_provider.dart` | 395 |
| `widgets/quotes_panel/quotes_panel.dart` | 369 |
| `widgets/library/library_sidebar.dart` | 292 |
| `widgets/tts/tts_toolbar.dart` | 287 |

---

## API Reference (TTS Backend)

The TTS backend runs on `http://localhost:8787`.

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/api/kokoro/voices` | GET | List available voices |
| `/api/kokoro/generate` | POST | Synthesize text to speech |
| `/api/kokoro/audio/list` | GET | List generated audio files |
| `/api/kokoro/audio/{filename}` | DELETE | Delete audio file |

### Generate Speech Example

```bash
curl -X POST http://localhost:8787/api/kokoro/generate \
  -H "Content-Type: application/json" \
  -d '{"text": "Hello, world!", "voice": "bf_emma", "speed": 1.0}'
```

---

## Dependencies

### Flutter/Dart

| Package | Version | Purpose |
|---------|---------|---------|
| `syncfusion_flutter_pdfviewer` | ^29.1.41 | PDF viewing |
| `syncfusion_flutter_pdf` | ^29.1.41 | PDF text extraction |
| `flutter_riverpod` | ^2.6.1 | State management |
| `file_picker` | ^8.1.7 | File selection dialogs |
| `desktop_drop` | ^0.4.4 | Drag-and-drop support |
| `path_provider` | ^2.1.5 | File system paths |
| `just_audio` | ^0.9.46 | Audio playback |
| `http` | ^1.3.0 | HTTP client |
| `uuid` | ^4.5.1 | Unique identifiers |

### Python (TTS Backend)

| Package | Version | Purpose |
|---------|---------|---------|
| `fastapi` | >=0.100.0 | Web framework |
| `uvicorn` | >=0.23.0 | ASGI server |
| `kokoro` | >=0.9.0 | TTS engine |
| `soundfile` | >=0.12.0 | Audio file I/O |
| `numpy` | >=1.24.0 | Numerical operations |

---

## Data Model

```dart
Source {
  id: String           // UUID
  title: String        // Book title
  author: String       // Author name(s)
  year: int            // Publication year
  publisher: String?   // Optional
  filePath: String     // Path to PDF
  quotes: List<Quote>  // Associated quotes
}

Quote {
  id: String           // UUID
  sourceId: String     // Parent source
  text: String         // Quote text
  pageNumber: int      // Page number
  notes: String?       // User notes
  order: int           // Manual ordering
}
```

---

## Troubleshooting

### Common Issues

**"TTS server not available"**
```bash
# Start the TTS server
cd backend
source .venv/bin/activate
python main.py
```

**"Kokoro models not found"**
```bash
# Download models (~350MB)
./scripts/bundle_kokoro.sh
```

**"PDF text selection not working"**
- Ensure the PDF contains selectable text (not scanned images)
- Some PDFs have copy protection that prevents text selection

**Flutter build fails**
```bash
flutter clean
flutter pub get
flutter build macos --release
```

**Port 8787 already in use**
```bash
lsof -i :8787
kill -9 <PID>
```

### Performance Tips

- **Large PDFs**: TTS extracts text in 10-page chunks for performance
- **Memory**: Close other apps when working with very large PDFs
- **Audio Generation**: First synthesis may take a moment while model loads
- **Apple Silicon**: Kokoro uses MPS acceleration for faster synthesis

---

## Limitations

- **Text-based PDFs only**: Scanned images require OCR (not built-in)
- **Citation format**: Fixed APA-style format (MLA, Chicago, BibTeX planned)
- **TTS Languages**: British English only (Kokoro limitation)
- **Platform**: macOS only

---

## Future Ideas

- [ ] Multiple citation formats (MLA, Chicago, BibTeX)
- [ ] PDF annotation persistence
- [ ] Quote tagging and categorization
- [ ] Full-text search across all quotes
- [ ] Cloud sync (optional)
- [ ] Import existing quote collections
- [ ] OCR for scanned PDFs

---

## Development Story

Mayari was designed to be:

1. **Purpose-built**: Not a general PDF reader—specifically for quote extraction
2. **Keyboard-first**: Most actions accessible via shortcuts
3. **Local-first**: All data stays on your machine
4. **Academic-focused**: Proper citation tracking from the start


---

## Author

| | |
|---|---|
| **Author** | Shlomo Kashani |
| **Affiliation** | Johns Hopkins University, Maryland, U.S.A. |

---

## Citation

```bibtex
@software{kashani2025mayari,
  title={Mayari: PDF Quote Extraction Tool for Academic Research},
  author={Kashani, Shlomo},
  year={2025},
  institution={Johns Hopkins University},
  url={https://github.com/BoltzmannEntropy/Mayari},
  note={Desktop application for extracting and organizing quotes from PDF books with automatic citation tracking}
}
```

**APA Format:**

Kashani, S. (2025). *Mayari: PDF Quote Extraction Tool for Academic Research*. Johns Hopkins University. https://github.com/BoltzmannEntropy/Mayari

**IEEE Format:**

S. Kashani, "Mayari: PDF Quote Extraction Tool for Academic Research," Johns Hopkins University, 2025. [Online]. Available: https://github.com/BoltzmannEntropy/Mayari

---

## License

MIT License - feel free to use, modify, and distribute.

---

## Acknowledgments

- [Kokoro TTS](https://github.com/hexgrad/kokoro) - Fast, high-quality British TTS
- [Syncfusion Flutter PDF](https://www.syncfusion.com/flutter-widgets/flutter-pdf-viewer) - Professional PDF rendering
- [Flutter](https://flutter.dev) - Cross-platform UI framework
- [Riverpod](https://riverpod.dev) - Reactive state management
- [FastAPI](https://fastapi.tiangolo.com) - Python API framework

---

<div align="center">
  <br>
  <i>Named after Mayari, the Philippine goddess of the moon — illuminating knowledge in the darkness.</i>
  <br><br>
  🌙
</div>
