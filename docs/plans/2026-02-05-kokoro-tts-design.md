# Kokoro TTS Integration Design

## Overview

Add text-to-speech functionality to Mayari using Kokoro TTS, enabling users to listen to PDF content with continuous audiobook-style reading.

## Requirements

- **TTS Engine**: Kokoro TTS via local HTTP server
- **Reading Mode**: Continuous reading from current position through pages
- **Voice Selection**: Toolbar dropdown + settings dialog for defaults
- **Server Management**: Auto-start when needed, bundled with app
- **Voices**: All British English voices bundled
- **Controls**: Full playback (Play/Pause, Stop, Skip, Speed, Voice)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Flutter App                             │
├─────────────────────────────────────────────────────────────┤
│  TTS Service (Dart)                                         │
│  ├── Manages Kokoro server lifecycle (start/stop)           │
│  ├── Sends text to server via HTTP                          │
│  ├── Receives audio stream, plays via audio player          │
│  └── Tracks reading position (page, paragraph)              │
├─────────────────────────────────────────────────────────────┤
│  TTS Provider (Riverpod)                                    │
│  ├── State: playing/paused/stopped, current position        │
│  ├── Voice selection, speed setting                         │
│  └── Coordinates with PDF provider for page text extraction │
├─────────────────────────────────────────────────────────────┤
│  UI Components                                               │
│  ├── TTS Toolbar (in PDF viewer pane)                       │
│  │   └── Play/Pause, Stop, Skip, Speed, Voice dropdown      │
│  └── Settings Dialog (voice default, speed default)         │
└─────────────────────────────────────────────────────────────┘
        │
        ▼ HTTP (localhost)
┌─────────────────────────────────────────────────────────────┐
│  Kokoro TTS Server (Python, bundled)                        │
│  ├── All British English voice models                       │
│  ├── REST API: POST /synthesize {text, voice, speed}        │
│  └── Returns: audio/wav stream                              │
└─────────────────────────────────────────────────────────────┘
```

## Bundled Assets

```
Mayari.app/Contents/
├── Resources/
│   └── kokoro/
│       ├── kokoro_server.py      # Simple HTTP wrapper
│       ├── kokoro/               # Kokoro library
│       ├── voices/
│       │   ├── bf_emma.pt        # British Female - Emma
│       │   ├── bf_isabella.pt    # British Female - Isabella
│       │   ├── bm_george.pt      # British Male - George
│       │   └── bm_lewis.pt       # British Male - Lewis
│       └── requirements.txt      # Python dependencies
```

## Server Lifecycle

- **On app launch**: Server stays dormant
- **On first Play**: Start server, wait for ready (~2-3 sec)
- **During playback**: Server stays running
- **On Stop or 30s idle**: Server kept warm
- **On app quit**: Kill server process cleanly

## Server API

```
GET  /health              → {"status": "ok", "voices": [...]}
POST /synthesize          → audio/wav
     {text, voice, speed}
GET  /voices              → [{id, name, gender, accent}]
```

## UI Design

### Toolbar Controls

```
[▶] [⏹] [⏮][⏭] │ 1.0x ▼ │ Emma ▼ │ [existing controls...]
```

- Play/Pause toggle
- Stop (resets to page start)
- Skip back/forward (paragraph)
- Speed dropdown (0.5x to 2.0x)
- Voice dropdown

### Visual States

| State | Play Button | Indicator |
|-------|-------------|-----------|
| Stopped | ▶ (gray) | None |
| Loading | Spinner | "Starting TTS..." |
| Playing | ⏸ (blue) | Highlight current paragraph |
| Paused | ▶ (blue) | Highlight remains |

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Space` | Play/Pause |
| `Escape` | Stop |
| `←` `→` | Skip paragraph |
| `↑` `↓` | Speed up/down |

## Settings Dialog

New TTS tab with:
- Default Voice dropdown + Preview button
- Default Speed dropdown
- Auto-advance Pages toggle
- Highlight Current Paragraph toggle

## Persistence

In `mayari_data.json`:

```json
{
  "tts": {
    "defaultVoice": "bf_emma",
    "defaultSpeed": 1.0,
    "autoAdvancePages": true,
    "highlightCurrentParagraph": true
  }
}
```

## New Files

```
lib/
├── services/
│   └── tts_service.dart
├── providers/
│   └── tts_provider.dart
├── widgets/
│   ├── tts/
│   │   ├── tts_toolbar.dart
│   │   └── tts_settings_tab.dart
│   └── dialogs/
│       └── settings_dialog.dart

macos/Runner/Resources/kokoro/
scripts/bundle_kokoro.sh
```

## Modified Files

- `pubspec.yaml` - Add dependencies
- `pdf_viewer_pane.dart` - Add toolbar, highlighting
- `workspace_screen.dart` - Add settings
- `storage_service.dart` - TTS settings persistence
- `macos/Runner.xcodeproj` - Bundle resources

## Dependencies

```yaml
just_audio: ^0.9.x
http: ^1.x
```
