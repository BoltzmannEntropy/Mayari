# Production Blocker Report - MayariCODE

**Project:** Mayari
**Date:** 2026-03-02
**Skill Used:** osx-blockers

## Executive Summary

- **P0 Blockers:** 0
- **P1 Critical:** 1
- **P2 Major:** 0
- **P3 Minor:** 0
- **Recommendation:** FIX BEFORE RELEASE

## P1 Critical Issues

### C001: Stream Subscriptions Not Cancelled in AudiobookPlaybackNotifier

**Category:** Memory Management
**File:** `lib/providers/audiobook_provider.dart:1070-1093`
**Severity:** P1 - Memory leak after repeated use

**Problem:**
The `AudiobookPlaybackNotifier` constructor creates three stream subscriptions but does not store them for cancellation in `dispose()`.

**Evidence:**
```dart
class AudiobookPlaybackNotifier extends StateNotifier<AudiobookPlaybackState> {
  final AudioPlayer _player = AudioPlayer();

  AudiobookPlaybackNotifier() : super(const AudiobookPlaybackState()) {
    // These subscriptions are created but never stored or cancelled
    _player.playerStateStream.listen((playerState) {  // Line 1074
      // ...
    });

    _player.positionStream.listen((position) {  // Line 1081
      // ...
    });

    _player.durationStream.listen((duration) {  // Line 1088
      // ...
    });
  }

  @override
  void dispose() {
    _player.dispose();  // Player disposed, but subscriptions may still fire
    super.dispose();
  }
}
```

**Impact:**
- Memory leak accumulates over time with repeated audiobook playback
- Stale callbacks may fire after notifier is disposed
- Potential "Bad state: Cannot add new events after calling close" exceptions

**Recommended Fix:**
```dart
class AudiobookPlaybackNotifier extends StateNotifier<AudiobookPlaybackState> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  AudiobookPlaybackNotifier() : super(const AudiobookPlaybackState()) {
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        state = const AudiobookPlaybackState();
      }
    });

    _positionSubscription = _player.positionStream.listen((position) {
      if (state.playingId != null) {
        state = state.copyWith(position: position);
      }
    });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null && state.playingId != null) {
        state = state.copyWith(duration: duration);
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}
```

---

## Memory Management Audit

| Resource | File:Line | Created | Disposed | Status |
|----------|-----------|---------|----------|--------|
| `_ticker` (Timer) | audiobook_jobs_panel.dart:21 | initState | dispose:29 | OK |
| `_wordTrackingTimer` | tts_provider.dart:204 | various | dispose:729 | OK |
| `_playbackWatchdogTimer` | tts_provider.dart:205 | various | dispose:729 | OK |
| `_downloadProgressController` | tts_service.dart:549 | field init | dispose:1050 | OK |
| `_audiobookProgressController` | tts_service.dart:946 | field init | dispose:1051 | OK |
| `_audioPlayer` | tts_service.dart:540 | field init | dispose:1052 | OK |
| `_progressSubscription` | audiobook_provider.dart:496 | _runGenerationJob | dispose:1064 | OK |
| `_player.playerStateStream` | audiobook_provider.dart:1074 | constructor | **NOT STORED** | **P1** |
| `_player.positionStream` | audiobook_provider.dart:1081 | constructor | **NOT STORED** | **P1** |
| `_player.durationStream` | audiobook_provider.dart:1088 | constructor | **NOT STORED** | **P1** |

## Busy Wait/Spin Loop Audit

| Pattern | File:Line | Check | Status |
|---------|-----------|-------|--------|
| `_waitForModelLoaded` | tts_service.dart:643-656 | Uses `Future.delayed` in loop | OK |
| `Future.doWhile` polling | tts_provider.dart:172-177 | Has `isActive` guard and 5s delay | OK |
| `_ticker` Timer.periodic | audiobook_jobs_panel.dart:21 | Has `mounted` check | OK |
| `_wordTrackingTimer` | tts_provider.dart:376 | Has state guards | OK |

## API Contract Audit

**Note:** MayariPRJ is a local-only Flutter app that uses native Swift TTS via MethodChannel. No backend HTTP API to audit.

| API Type | Status |
|----------|--------|
| Native MethodChannel | Uses `com.mayari.tts` channel |
| Backend HTTP API | N/A (pure local app) |

## UI Workflow Audit

| Workflow | Entry Point | Trace Complete | Blockers |
|----------|-------------|----------------|----------|
| Open Document | _openDocument() | YES | None |
| Load Examples | _loadExamples() | YES | None - uses context.mounted |
| TTS Playback | play() | YES | None |
| Audiobook Generation | enqueue() | YES | None |
| Job Retry | retry() | YES | None |
| Audiobook Playback | play(book) | YES | None |

## Positive Observations

1. **Timer Management:** The `AudiobookJobsPanel` correctly stores and cancels its ticker timer
2. **StateNotifier Disposal:** `TtsNotifier` properly cancels both timers in dispose()
3. **StreamController Closure:** `TtsService` properly closes its StreamControllers
4. **Mounted Checks:** `_loadExamples` checks `context.mounted` before showing SnackBar
5. **Error Handling:** Good try/catch patterns throughout with user feedback
6. **Bounded Polling:** `ttsServerStatusProvider` uses `isActive` flag to stop polling

## Recommendations

1. **[P1] Fix AudiobookPlaybackNotifier subscriptions** - Store and cancel the three stream subscriptions to prevent memory leaks
2. Consider adding integration tests for long audiobook playback sessions to catch memory growth
