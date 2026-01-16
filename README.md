# Mayari

A cross-platform PDF quote extraction tool for academic research, built with Flutter.

**Built in a single session with [Claude Code](https://claude.ai/claude-code)** — from idea to working app in under 30 minutes.

![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Windows%20%7C%20Linux-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter)
![License](https://img.shields.io/badge/license-MIT-green)

## What It Does

Mayari helps researchers extract and organize quotes from PDF books with proper citations:

- **Read PDFs** in a clean viewer with zoom and navigation controls
- **Select text** and capture it as quotes with automatic page number tracking
- **Organize quotes** grouped by source with full bibliographic metadata
- **Export to Markdown** with properly formatted citations

## The Story: Building with Claude Code

This project was built to demonstrate how quickly you can go from idea to working application using Claude Code with the "superpowers" skill system.

### The Prompt

> "Let's try Flutter. Project should be under Mayari, it should allow uploading a PDF book file, user can read and page like any other PDF viewer on the left pane, then he can mark sections or lines, then they are copied to a text editing pane to the right, with the correct line numbers the quote was taken from."

### What Happened

1. **Brainstorming phase** (~5 minutes): Claude asked clarifying questions one at a time:
   - Primary use case? → Academic research
   - What citation info to capture? → Full bibliographic (author, title, year, publisher)
   - How to organize quotes? → Grouped by source
   - Export format? → Markdown
   - Selection modes? → Both standard and highlight mode
   - Target platforms? → All desktop (macOS, Windows, Linux)

2. **Design documentation** (~2 minutes): A complete design spec was written to `docs/plans/`

3. **Implementation** (~20 minutes):
   - Installed Flutter via Homebrew
   - Created project structure with models, providers, services, widgets
   - Implemented PDF viewer with Syncfusion
   - Built quotes panel with source management
   - Added persistence and export
   - Fixed macOS sandboxing entitlements

4. **Result**: A fully functional app, committed to git, ready to use.

## UI Design

### Two-Pane Layout

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

### Design Decisions

- **Resizable splitter**: Drag the divider to adjust pane widths (30%-80% range)
- **Platform-adaptive styling**: Cupertino feel on macOS, Material on Windows/Linux
- **Dark mode support**: Follows system preference automatically
- **Minimal chrome**: Focus on content, not UI clutter

### Selection Modes

| Mode | How It Works |
|------|--------------|
| **Standard** | Select text → Click "Add to Quotes" button or press `Cmd+D` |
| **Highlight** | Toggle on → Any selection automatically captures to quotes |

Highlight mode shows an orange border around the PDF viewer as a visual indicator.

## Implementation Details

### Tech Stack

| Component | Technology |
|-----------|------------|
| Framework | Flutter 3.38 |
| PDF Viewer | Syncfusion Flutter PDF Viewer |
| State Management | Riverpod |
| Persistence | JSON file storage |
| Platforms | macOS, Windows, Linux |

### Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   ├── source.dart          # PDF source with bibliographic metadata
│   └── quote.dart           # Extracted quote with page number
├── providers/
│   ├── sources_provider.dart # State management for sources & quotes
│   └── pdf_provider.dart     # PDF viewer state (page, selection)
├── screens/
│   └── workspace_screen.dart # Main two-pane layout
├── widgets/
│   ├── pdf_viewer/
│   │   └── pdf_viewer_pane.dart
│   ├── quotes_panel/
│   │   ├── quotes_panel.dart
│   │   ├── source_header.dart
│   │   └── quote_card.dart
│   └── dialogs/
│       ├── source_metadata_dialog.dart
│       └── quote_edit_dialog.dart
└── services/
    ├── storage_service.dart  # JSON persistence
    └── export_service.dart   # Markdown export
```

### Data Model

```dart
Source {
  id: String
  title: String
  author: String
  year: int
  publisher: String?
  filePath: String
  quotes: List<Quote>
}

Quote {
  id: String
  sourceId: String
  text: String
  pageNumber: int
  notes: String?
  order: int
}
```

### Persistence

Data is stored in `~/Documents/mayari_data.json` and auto-saves on every change. The format is simple JSON for easy backup and portability.

### Export Format

```markdown
# Collected Quotes

## "Book Title" by Author (Year). Publisher.

> "First quote text here..."
>
> — p. 42

> "Second quote with user notes..."
>
> — p. 78
>
> *Note: Important for methodology section*
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) 3.x or later
- For macOS: Xcode and CocoaPods
- For Windows: Visual Studio with C++ workload
- For Linux: GTK development libraries

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd Mayari

# Install dependencies
flutter pub get

# Run on your platform
flutter run -d macos    # or windows, linux
```

### Building for Release

```bash
flutter build macos    # Creates .app bundle
flutter build windows  # Creates .exe
flutter build linux    # Creates binary
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd/Ctrl + H` | Toggle highlight mode |
| `Cmd/Ctrl + D` | Add selected text to quotes |
| `←` `→` | Previous/next page |

## Limitations

- **Scanned PDFs**: Text selection requires the PDF to have selectable text (not scanned images). Use OCR preprocessing for scanned documents.
- **Complex layouts**: Multi-column PDFs may have text selection issues depending on how the PDF was created.

## Future Ideas

These are not currently implemented but could be added:

- [ ] Citation format options (APA, MLA, Chicago, BibTeX)
- [ ] PDF annotation persistence (highlights saved to PDF)
- [ ] Cloud sync for quotes
- [ ] Tag/categorize quotes by theme
- [ ] Search across all quotes
- [ ] Import existing quote collections

## License

MIT License - feel free to use, modify, and distribute.

## Acknowledgments

- Built with [Claude Code](https://claude.ai/claude-code) by Anthropic
- PDF rendering by [Syncfusion Flutter PDF Viewer](https://pub.dev/packages/syncfusion_flutter_pdfviewer)
- State management with [Riverpod](https://riverpod.dev/)

---

*"Mayari" is named after the Philippine goddess of the moon — illuminating knowledge in the darkness.*
