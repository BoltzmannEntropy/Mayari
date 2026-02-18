import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../services/backend_service.dart';
import '../services/log_service.dart';
import '../services/tts_service.dart';

/// TTS playback state
enum TtsPlaybackState { stopped, loading, playing, paused }

/// State for TTS functionality
class TtsState {
  final TtsPlaybackState playbackState;
  final String currentVoice;
  final double speed;
  final int currentParagraphIndex;
  final int totalParagraphs;
  final List<String> paragraphs;
  final String? errorMessage;
  final bool autoAdvancePages;
  final bool highlightCurrentParagraph;

  const TtsState({
    this.playbackState = TtsPlaybackState.stopped,
    this.currentVoice = 'bf_emma',
    this.speed = 1.0,
    this.currentParagraphIndex = 0,
    this.totalParagraphs = 0,
    this.paragraphs = const [],
    this.errorMessage,
    this.autoAdvancePages = true,
    this.highlightCurrentParagraph = true,
  });

  TtsState copyWith({
    TtsPlaybackState? playbackState,
    String? currentVoice,
    double? speed,
    int? currentParagraphIndex,
    int? totalParagraphs,
    List<String>? paragraphs,
    String? errorMessage,
    bool? autoAdvancePages,
    bool? highlightCurrentParagraph,
  }) {
    return TtsState(
      playbackState: playbackState ?? this.playbackState,
      currentVoice: currentVoice ?? this.currentVoice,
      speed: speed ?? this.speed,
      currentParagraphIndex:
          currentParagraphIndex ?? this.currentParagraphIndex,
      totalParagraphs: totalParagraphs ?? this.totalParagraphs,
      paragraphs: paragraphs ?? this.paragraphs,
      errorMessage: errorMessage,
      autoAdvancePages: autoAdvancePages ?? this.autoAdvancePages,
      highlightCurrentParagraph:
          highlightCurrentParagraph ?? this.highlightCurrentParagraph,
    );
  }

  bool get isPlaying => playbackState == TtsPlaybackState.playing;
  bool get isPaused => playbackState == TtsPlaybackState.paused;
  bool get isStopped => playbackState == TtsPlaybackState.stopped;
  bool get isLoading => playbackState == TtsPlaybackState.loading;
}

/// TTS settings that persist
class TtsSettings {
  final String defaultVoice;
  final double defaultSpeed;
  final bool autoAdvancePages;
  final bool highlightCurrentParagraph;

  const TtsSettings({
    this.defaultVoice = 'bf_emma',
    this.defaultSpeed = 1.0,
    this.autoAdvancePages = true,
    this.highlightCurrentParagraph = true,
  });

  factory TtsSettings.fromJson(Map<String, dynamic> json) {
    return TtsSettings(
      defaultVoice: json['defaultVoice'] as String? ?? 'bf_emma',
      defaultSpeed: (json['defaultSpeed'] as num?)?.toDouble() ?? 1.0,
      autoAdvancePages: json['autoAdvancePages'] as bool? ?? true,
      highlightCurrentParagraph:
          json['highlightCurrentParagraph'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'defaultVoice': defaultVoice,
      'defaultSpeed': defaultSpeed,
      'autoAdvancePages': autoAdvancePages,
      'highlightCurrentParagraph': highlightCurrentParagraph,
    };
  }
}

/// Provider for TTS service instance
final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for backend startup/status messages.
final backendStatusProvider = StreamProvider.autoDispose<String>((ref) {
  final backend = BackendService();
  final controller = StreamController<String>();
  controller.add(backend.currentStatus);
  final sub = backend.statusStream.listen(controller.add);
  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });
  return controller.stream;
});

/// Provider for TTS server status (checks periodically)
final ttsServerStatusProvider = StreamProvider.autoDispose<bool>((ref) async* {
  final service = ref.watch(ttsServiceProvider);
  final controller = StreamController<bool>();
  var isActive = true;

  Future<void> emitHealth() async {
    if (!isActive) {
      return;
    }
    try {
      controller.add(await service.isServerHealthy());
    } catch (_) {
      controller.add(false);
    }
  }

  // Emit immediately for first paint.
  await emitHealth();

  unawaited(
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 5));
      await emitHealth();
      return isActive;
    }),
  );

  ref.onDispose(() {
    isActive = false;
    controller.close();
  });

  yield* controller.stream;
});

/// Provider for available voices
final ttsVoicesProvider = FutureProvider<List<TtsVoice>>((ref) async {
  final service = ref.watch(ttsServiceProvider);
  return service.getVoices();
});

/// Notifier for TTS state management
class TtsNotifier extends StateNotifier<TtsState> {
  final TtsService _service;
  final LogService _log;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  TtsNotifier(this._service, this._log) : super(const TtsState()) {
    _setupPlayerListener();
  }

  void _setupPlayerListener() {
    _playerStateSubscription = _service.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        // Current paragraph finished, move to next
        _onParagraphComplete();
      }
    });
  }

  void _onParagraphComplete() {
    if (state.currentParagraphIndex < state.paragraphs.length - 1) {
      // Move to next paragraph
      _playNextParagraph();
    } else {
      // All paragraphs done
      state = state.copyWith(
        playbackState: TtsPlaybackState.stopped,
        currentParagraphIndex: 0,
      );
    }
  }

  Future<void> _playNextParagraph() async {
    final nextIndex = state.currentParagraphIndex + 1;
    if (nextIndex >= state.paragraphs.length) {
      await stop();
      return;
    }

    state = state.copyWith(
      currentParagraphIndex: nextIndex,
      playbackState: TtsPlaybackState.loading,
    );

    final text = state.paragraphs[nextIndex];
    final success = await _service.speak(
      text,
      voice: state.currentVoice,
      speed: state.speed,
    );

    if (success) {
      state = state.copyWith(playbackState: TtsPlaybackState.playing);
    } else {
      state = state.copyWith(
        playbackState: TtsPlaybackState.stopped,
        errorMessage: 'Failed to play paragraph',
      );
    }
  }

  /// Set the text content to read (split into paragraphs)
  void setContent(String text) {
    _log.info('TTS', 'Setting content: ${text.length} chars');

    final normalizedText = text
        .replaceAll('\u00A0', ' ')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    // Split text into paragraphs (by double newlines or significant breaks).
    final paragraphs = normalizedText
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // If we have a single long block, split by sentence and then by target size.
    if (paragraphs.length == 1 && paragraphs[0].length > 500) {
      final sentences = paragraphs[0]
          .split(RegExp(r'(?<=[.!?])\s+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      const targetChunkChars = 900;
      final chunks = <String>[];
      final currentChunk = <String>[];
      var currentChars = 0;

      for (final sentence in sentences) {
        final sentenceLen = sentence.length + (currentChunk.isEmpty ? 0 : 1);
        if (currentChunk.isNotEmpty &&
            (currentChars + sentenceLen > targetChunkChars)) {
          chunks.add(currentChunk.join(' '));
          currentChunk.clear();
          currentChars = 0;
        }
        currentChunk.add(sentence);
        currentChars += sentenceLen;
      }
      if (currentChunk.isNotEmpty) {
        chunks.add(currentChunk.join(' '));
      }

      _log.debug('TTS', 'Split into ${chunks.length} chunks');
      state = state.copyWith(
        paragraphs: chunks,
        totalParagraphs: chunks.length,
        currentParagraphIndex: 0,
      );
    } else {
      _log.debug('TTS', 'Split into ${paragraphs.length} paragraphs');
      state = state.copyWith(
        paragraphs: paragraphs,
        totalParagraphs: paragraphs.length,
        currentParagraphIndex: 0,
      );
    }
  }

  /// Start playing from the current paragraph
  Future<void> play() async {
    _log.info('TTS', 'Starting playback');
    _log.debug(
      'TTS',
      'paragraphs=${state.paragraphs.length}, currentIndex=${state.currentParagraphIndex}',
    );

    if (state.paragraphs.isEmpty) {
      _log.warning('TTS', 'No paragraphs to play');
      state = state.copyWith(errorMessage: 'No content to read');
      return;
    }

    state = state.copyWith(
      playbackState: TtsPlaybackState.loading,
      errorMessage: null,
    );

    final text = state.paragraphs[state.currentParagraphIndex];
    final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
    _log.info(
      'TTS',
      'Playing paragraph ${state.currentParagraphIndex + 1}/${state.paragraphs.length}: "$preview"',
    );

    final success = await _service.speak(
      text,
      voice: state.currentVoice,
      speed: state.speed,
    );

    if (success) {
      _log.info('TTS', 'Playback started successfully');
      state = state.copyWith(playbackState: TtsPlaybackState.playing);
    } else {
      _log.error('TTS', 'Failed to start playback - check Kokoro server');
      state = state.copyWith(
        playbackState: TtsPlaybackState.stopped,
        errorMessage: 'Failed to start TTS. Make sure Kokoro is set up.',
      );
    }
  }

  /// Pause playback
  Future<void> pause() async {
    _log.info('TTS', 'Paused');
    await _service.pause();
    state = state.copyWith(playbackState: TtsPlaybackState.paused);
  }

  /// Resume playback
  Future<void> resume() async {
    _log.info('TTS', 'Resumed');
    await _service.resume();
    state = state.copyWith(playbackState: TtsPlaybackState.playing);
  }

  /// Stop playback and reset position
  Future<void> stop() async {
    _log.info('TTS', 'Stopped');
    await _service.stop();
    state = state.copyWith(
      playbackState: TtsPlaybackState.stopped,
      currentParagraphIndex: 0,
    );
  }

  /// Skip to next paragraph
  Future<void> skipForward() async {
    if (state.currentParagraphIndex < state.paragraphs.length - 1) {
      // Capture playing state BEFORE stopping
      final wasActive = state.isPlaying || state.isPaused;
      await _service.stop();
      state = state.copyWith(
        currentParagraphIndex: state.currentParagraphIndex + 1,
        playbackState: TtsPlaybackState.stopped,
      );
      if (wasActive) {
        await play();
      }
    }
  }

  /// Skip to previous paragraph
  Future<void> skipBackward() async {
    if (state.currentParagraphIndex > 0) {
      // Capture playing state BEFORE stopping
      final wasActive = state.isPlaying || state.isPaused;
      await _service.stop();
      state = state.copyWith(
        currentParagraphIndex: state.currentParagraphIndex - 1,
        playbackState: TtsPlaybackState.stopped,
      );
      if (wasActive) {
        await play();
      }
    }
  }

  /// Set the voice to use - restarts playback if currently playing
  Future<void> setVoice(String voiceId) async {
    if (voiceId == state.currentVoice) return;

    _log.info('TTS', 'Voice changed to: $voiceId');

    // If currently playing, restart with new voice
    final wasPlaying = state.isPlaying;

    if (wasPlaying) {
      await _service.stop();
    }

    state = state.copyWith(currentVoice: voiceId);

    // Restart playback with new voice
    if (wasPlaying && state.paragraphs.isNotEmpty) {
      await play();
    }
  }

  /// Set playback speed
  void setSpeed(double speed) {
    _log.info('TTS', 'Speed changed to: ${speed}x');
    state = state.copyWith(speed: speed);
    _service.setSpeed(speed);
  }

  /// Update settings
  void updateSettings({
    bool? autoAdvancePages,
    bool? highlightCurrentParagraph,
  }) {
    state = state.copyWith(
      autoAdvancePages: autoAdvancePages,
      highlightCurrentParagraph: highlightCurrentParagraph,
    );
  }

  /// Load settings from persistence
  void loadSettings(TtsSettings settings) {
    state = state.copyWith(
      currentVoice: settings.defaultVoice,
      speed: settings.defaultSpeed,
      autoAdvancePages: settings.autoAdvancePages,
      highlightCurrentParagraph: settings.highlightCurrentParagraph,
    );
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for TTS state
final ttsProvider = StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  final service = ref.watch(ttsServiceProvider);
  final logService = ref.watch(logServiceProvider.notifier);
  return TtsNotifier(service, logService);
});

/// Available speed options
const List<double> speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Speed option display names
String speedDisplayName(double speed) {
  if (speed == 1.0) return '1.0x';
  return '${speed}x';
}
