# Mayari - PDF Quote Extraction Tool

**Date:** 2025-01-16
**Purpose:** Academic research tool for extracting and organizing quotes from PDF books with proper citations.

## Overview

Mayari is a cross-platform desktop application (macOS, Windows, Linux) built with Flutter. It provides a two-pane interface: a PDF viewer on the left for reading and selecting text, and a quotes panel on the right for organizing extracted passages with bibliographic metadata.

## Target Users

Academic researchers who need to:
- Read PDF books and papers
- Extract quotes with proper page references
- Organize quotes by source
- Export collected quotes for use in papers

## Architecture

### Two-Pane Layout

- **Left pane (60%)**: PDF viewer with navigation and text selection
- **Right pane (40%)**: Quotes library grouped by source
- **Resizable splitter** between panes

### Data Model

```
Source (PDF metadata)
├── id
├── title
├── author
├── year
├── publisher (optional)
├── filePath
└── quotes[]

Quote
├── id
├── sourceId
├── text
├── pageNumber
├── notes (optional user annotation)
├── createdAt
└── order (for manual sorting)
```

### Technology Stack

- **Framework**: Flutter (desktop: macOS, Windows, Linux)
- **PDF Rendering**: `syncfusion_flutter_pdfviewer`
- **State Management**: `flutter_riverpod`
- **Local Database**: `isar` or `hive`
- **Styling**: Platform-adaptive (Cupertino on macOS, Material elsewhere)

### Project Structure

```
lib/
├── main.dart
├── models/
│   ├── source.dart
│   └── quote.dart
├── providers/
│   ├── sources_provider.dart
│   ├── quotes_provider.dart
│   └── pdf_provider.dart
├── screens/
│   └── workspace_screen.dart
├── widgets/
│   ├── pdf_viewer/
│   │   ├── pdf_viewer_pane.dart
│   │   ├── page_controls.dart
│   │   └── selection_toolbar.dart
│   ├── quotes_panel/
│   │   ├── quotes_panel.dart
│   │   ├── source_header.dart
│   │   └── quote_card.dart
│   └── dialogs/
│       ├── source_metadata_dialog.dart
│       └── export_dialog.dart
└── services/
    ├── pdf_service.dart
    ├── database_service.dart
    └── export_service.dart
```

## Features

### PDF Viewer

**Navigation:**
- Previous/next page buttons
- Direct page number input
- Collapsible thumbnail sidebar
- Keyboard shortcuts (arrow keys, Page Up/Down)

**Zoom:**
- Fit to width / fit to page
- Percentage slider (50% - 200%)
- Pinch-to-zoom on trackpad

**Document handling:**
- Open via file picker or drag-and-drop
- Remember last position per document
- Display filename in title bar

### Text Selection

**Standard Mode (default):**
- Click and drag to select text
- Floating action button appears: "Add to Quotes"
- Keyboard shortcut: Cmd/Ctrl+D sends selection
- Selection clears after adding

**Highlight Mode (toggle):**
- Toolbar toggle button activates mode
- Visual indicator shows mode is active (border tint)
- Any text selection automatically sends to quotes pane
- Toast notification confirms each capture
- Toggle off to return to standard mode

**Limitations:**
- If PDF has no selectable text (scanned images), display message suggesting OCR preprocessing

### Source Management

**First-time PDF open:**
- Modal dialog prompts for bibliographic info
- Pre-fill title from PDF metadata if available
- Required: Title, Author, Year
- Optional: Publisher

**Source operations:**
- Edit metadata via source settings
- Switch between sources via dropdown
- Remove source (option to keep or delete associated quotes)

### Quotes Panel

**Layout:**
- Source selector dropdown at top
- Collapsible source sections
- Quote cards within each source

**Quote card displays:**
- Quote text (expandable if long, >150 chars)
- Page number badge
- Edit button (modify text, add notes)
- Delete button (with confirmation)
- Drag handle for reordering

**Organization:**
- Quotes grouped under source headers
- Manual reorder via drag-and-drop within source
- Collapse/expand source sections

### Export

**Markdown format:**
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
> *Note: User's annotation here*
```

**Export options:**
- Export all sources or select specific ones
- Save to `.md` file via system picker
- Copy to clipboard

### Persistence

**Auto-save:**
- Save on every change (quotes, sources, metadata)
- No manual save required

**Stored data:**
- All sources and quotes in local database
- Recent PDF file paths
- Window size and splitter position
- Last active source

**Session restoration:**
- Prompt to restore last session on launch
- Recent Sources list in File menu

## Platform Considerations

**macOS:**
- Cupertino-style widgets
- Native file picker
- Menu bar integration
- Trackpad gestures

**Windows/Linux:**
- Material Design widgets
- Native file dialogs
- Standard window controls

## Future Considerations (Out of Scope)

These are explicitly NOT part of the initial build:
- OCR for scanned PDFs
- Cloud sync
- Collaboration features
- Citation format switching (APA, MLA, Chicago)
- PDF annotation/highlighting persistence
- Mobile versions
