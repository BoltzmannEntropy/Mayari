import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final String currentPreviewText;
  final List<String> currentWords;
  final int currentWordIndex;
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
    this.currentPreviewText = '',
    this.currentWords = const [],
    this.currentWordIndex = -1,
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
    String? currentPreviewText,
    List<String>? currentWords,
    int? currentWordIndex,
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
      currentPreviewText: currentPreviewText ?? this.currentPreviewText,
      currentWords: currentWords ?? this.currentWords,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
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

/// Provider for TTS status messages (native Swift TTS).
final ttsStatusProvider = StreamProvider.autoDispose<String>((ref) async* {
  final service = ref.watch(ttsServiceProvider);

  try {
    // Check native availability
    final available = await service.isNativeAvailable();
    if (!available) {
      yield 'Native TTS requires macOS 15.0+';
      return;
    }

    // Check if model is downloaded
    final downloaded = await service.isModelDownloaded();
    if (!downloaded) {
      yield 'TTS model not downloaded';
      return;
    }

    // Check if model is loaded
    final status = await service.getModelStatus();
    if (status['loaded'] == true) {
      yield 'TTS ready';
    } else if (status['loading'] == true) {
      yield 'Loading TTS model...';
    } else {
      yield 'TTS idle';
    }
  } catch (e) {
    yield 'TTS unavailable';
  }
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
      // Don't attempt auto-start during status checks to avoid crashes
      controller.add(await service.isServerHealthy(attemptAutoStart: false));
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

/// Selected language filters for voice cards. Empty means all languages.
final selectedVoiceLanguageCodesProvider = StateProvider<Set<String>>((ref) {
  return <String>{};
});

/// Notifier for TTS state management
class TtsNotifier extends StateNotifier<TtsState> {
  final TtsService _service;
  final LogService _log;
  bool _resumeNeedsResynthesis = false;
  Timer? _wordTrackingTimer;
  Timer? _playbackWatchdogTimer;
  DateTime? _trackingStartedAt;
  Duration _elapsedBeforeTracking = Duration.zero;
  List<int> _wordTimings = const [];
  int _trackingParagraphIndex = -1;
  bool _isAdvancingParagraph = false;
  bool _isCheckingPlayback = false;

  TtsNotifier(this._service, this._log) : super(const TtsState());

  List<String> _extractTrackableWords(String text) {
    final words = <String>[];
    for (final token in text.split(RegExp(r'\s+'))) {
      final clean = token.toLowerCase().replaceAll(
        RegExp(r'^[^a-z0-9]+|[^a-z0-9]+$'),
        '',
      );
      if (clean.length >= 2) {
        words.add(clean);
      }
    }
    return words;
  }

  int _estimateSentenceDurationMs(List<String> words, double speed) {
    if (words.isEmpty) return 0;
    final totalChars = words.fold<int>(0, (sum, w) => sum + w.length);
    final baseMs = ((words.length / 4.2) * 1000).round();
    final charMs = (totalChars * 22).round();
    final adjusted = ((baseMs + charMs) / speed).round();
    return adjusted.clamp(600, 20000);
  }

  List<int> _calculateWordTimings(List<String> words, int totalMs) {
    if (words.isEmpty) return const [];

    var totalWeight = 0;
    for (final word in words) {
      totalWeight += word.length + 2;
    }
    final msPerWeight = totalMs / totalWeight;

    final timings = <int>[];
    var cumulativeMs = 0;
    for (final word in words) {
      timings.add(cumulativeMs);
      cumulativeMs += ((word.length + 2) * msPerWeight).round();
    }
    return timings;
  }

  List<String> _chunkParagraph(String paragraph, {int targetChunkChars = 900}) {
    final trimmed = paragraph.trim();
    if (trimmed.isEmpty) return const [];
    if (trimmed.length <= targetChunkChars) return [trimmed];

    final sentences = trimmed
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (sentences.isEmpty ||
        (sentences.length == 1 && sentences.first == trimmed)) {
      final chunks = <String>[];
      var start = 0;
      while (start < trimmed.length) {
        final end = (start + targetChunkChars).clamp(0, trimmed.length);
        chunks.add(trimmed.substring(start, end).trim());
        start = end;
      }
      return chunks.where((c) => c.isNotEmpty).toList();
    }

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

    return chunks.where((c) => c.isNotEmpty).toList();
  }

  int _wordIndexForElapsed(Duration elapsed) {
    if (_wordTimings.isEmpty) return -1;
    final ms = elapsed.inMilliseconds;
    var index = 0;
    for (var i = 0; i < _wordTimings.length; i++) {
      if (ms >= _wordTimings[i]) {
        index = i;
      }
    }
    return index;
  }

  void _resetTrackingState({required bool clearPreview}) {
    _wordTrackingTimer?.cancel();
    _playbackWatchdogTimer?.cancel();
    _wordTrackingTimer = null;
    _playbackWatchdogTimer = null;
    _trackingStartedAt = null;
    _elapsedBeforeTracking = Duration.zero;
    _wordTimings = const [];
    _trackingParagraphIndex = -1;
    _isCheckingPlayback = false;
    if (clearPreview) {
      state = state.copyWith(
        currentPreviewText: '',
        currentWords: const [],
        currentWordIndex: -1,
      );
    }
  }

  void _pauseWordTracking() {
    if (_trackingStartedAt != null) {
      _elapsedBeforeTracking += DateTime.now().difference(_trackingStartedAt!);
    }
    _trackingStartedAt = null;
    _wordTrackingTimer?.cancel();
    _playbackWatchdogTimer?.cancel();
  }

  Future<void> _checkPlaybackCompletion(int paragraphIndex) async {
    if (_isCheckingPlayback || _isAdvancingParagraph) return;
    _isCheckingPlayback = true;
    try {
      final isPlayingNative = await _service.isNativePlaying();
      if (!isPlayingNative &&
          state.isPlaying &&
          state.currentParagraphIndex == paragraphIndex) {
        await _onParagraphComplete();
      }
    } finally {
      _isCheckingPlayback = false;
    }
  }

  void _startWordTracking(
    String text, {
    Duration startElapsed = Duration.zero,
  }) {
    final words = _extractTrackableWords(text);
    final totalMs = _estimateSentenceDurationMs(words, state.speed);
    _wordTimings = _calculateWordTimings(words, totalMs);
    _elapsedBeforeTracking = startElapsed;
    _trackingStartedAt = DateTime.now();
    _trackingParagraphIndex = state.currentParagraphIndex;

    final initialIndex = _wordIndexForElapsed(_elapsedBeforeTracking);
    state = state.copyWith(
      currentPreviewText: text,
      currentWords: words,
      currentWordIndex: initialIndex,
    );

    _wordTrackingTimer?.cancel();
    _wordTrackingTimer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      if (!state.isPlaying ||
          state.currentParagraphIndex != _trackingParagraphIndex) {
        return;
      }
      if (_trackingStartedAt == null) return;
      final elapsed =
          _elapsedBeforeTracking +
          DateTime.now().difference(_trackingStartedAt!);
      final nextIndex = _wordIndexForElapsed(elapsed);
      if (nextIndex != state.currentWordIndex) {
        state = state.copyWith(currentWordIndex: nextIndex);
      }
    });

    _playbackWatchdogTimer?.cancel();
    _playbackWatchdogTimer = Timer.periodic(const Duration(milliseconds: 220), (
      _,
    ) {
      if (!state.isPlaying ||
          state.currentParagraphIndex != _trackingParagraphIndex) {
        return;
      }
      unawaited(_checkPlaybackCompletion(_trackingParagraphIndex));
    });
  }

  Future<void> _onParagraphComplete() async {
    if (_isAdvancingParagraph) return;
    _isAdvancingParagraph = true;
    try {
      _resetTrackingState(clearPreview: false);
      if (state.currentParagraphIndex < state.paragraphs.length - 1) {
        // Move to next paragraph
        await _playNextParagraph();
      } else {
        // All paragraphs done
        state = state.copyWith(
          playbackState: TtsPlaybackState.stopped,
          currentParagraphIndex: 0,
          currentPreviewText: '',
          currentWords: const [],
          currentWordIndex: -1,
        );
      }
    } finally {
      _isAdvancingParagraph = false;
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
    final words = _extractTrackableWords(text);
    state = state.copyWith(
      currentPreviewText: text,
      currentWords: words,
      currentWordIndex: -1,
    );
    final success = await _service
        .speak(text, voice: state.currentVoice, speed: state.speed)
        .timeout(const Duration(seconds: 12), onTimeout: () => false);

    if (success) {
      state = state.copyWith(playbackState: TtsPlaybackState.playing);
      _startWordTracking(text);
    } else {
      _resetTrackingState(clearPreview: false);
      state = state.copyWith(
        playbackState: TtsPlaybackState.stopped,
        errorMessage: 'Failed to play paragraph',
      );
    }
  }

  /// Set the text content to read (split into paragraphs)
  void setContent(String text) {
    _log.info('TTS', 'Setting content: ${text.length} chars');
    _resetTrackingState(clearPreview: true);
    _resumeNeedsResynthesis = false;

    final normalizedText = text
        .replaceAll('\u00A0', ' ')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'\$[0-9]+'), ' ')
        .replaceAllMapped(
          RegExp(r'([.!?;:,])(?=[A-Za-z])'),
          (m) => '${m.group(1)} ',
        )
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();

    // Split text into paragraphs (by double newlines or significant breaks).
    final paragraphs = normalizedText
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    const targetChunkChars = 80;
    final chunks = <String>[];
    for (final paragraph in paragraphs) {
      chunks.addAll(
        _chunkParagraph(paragraph, targetChunkChars: targetChunkChars),
      );
    }

    _log.debug('TTS', 'Split into ${chunks.length} chunks');
    state = state.copyWith(
      paragraphs: chunks,
      totalParagraphs: chunks.length,
      currentParagraphIndex: 0,
      currentPreviewText: '',
      currentWords: const [],
      currentWordIndex: -1,
    );
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

    _resumeNeedsResynthesis = false;
    _resetTrackingState(clearPreview: false);

    state = state.copyWith(
      playbackState: TtsPlaybackState.loading,
      errorMessage: null,
    );

    final text = state.paragraphs[state.currentParagraphIndex];
    final words = _extractTrackableWords(text);
    state = state.copyWith(
      currentPreviewText: text,
      currentWords: words,
      currentWordIndex: -1,
    );
    final preview = text.length > 50 ? '${text.substring(0, 50)}...' : text;
    _log.info(
      'TTS',
      'Playing paragraph ${state.currentParagraphIndex + 1}/${state.paragraphs.length}: "$preview"',
    );

    final success = await _service
        .speak(text, voice: state.currentVoice, speed: state.speed)
        .timeout(const Duration(seconds: 12), onTimeout: () => false);

    if (success) {
      _log.info('TTS', 'Playback started successfully');
      state = state.copyWith(playbackState: TtsPlaybackState.playing);
      _startWordTracking(text);
    } else {
      _log.error('TTS', 'Failed to start playback - check Kokoro server');
      _resetTrackingState(clearPreview: false);
      state = state.copyWith(
        playbackState: TtsPlaybackState.stopped,
        errorMessage: 'Failed to start TTS. Make sure Kokoro is set up.',
      );
    }
  }

  /// Pause playback
  Future<void> pause() async {
    _log.info('TTS', 'Paused');
    _pauseWordTracking();
    await _service.pause();
    state = state.copyWith(playbackState: TtsPlaybackState.paused);
  }

  /// Resume playback
  Future<void> resume() async {
    if (_resumeNeedsResynthesis) {
      _resumeNeedsResynthesis = false;
      _log.info('TTS', 'Resuming with re-synthesized voice');
      await play();
      return;
    }

    _log.info('TTS', 'Resumed');
    await _service.resume();
    state = state.copyWith(playbackState: TtsPlaybackState.playing);
    if (state.currentPreviewText.isNotEmpty) {
      _startWordTracking(
        state.currentPreviewText,
        startElapsed: _elapsedBeforeTracking,
      );
    }
  }

  /// Stop playback and reset position
  Future<void> stop() async {
    _log.info('TTS', 'Stopped');
    _resumeNeedsResynthesis = false;
    _resetTrackingState(clearPreview: true);
    await _service.stop();
    state = state.copyWith(
      playbackState: TtsPlaybackState.stopped,
      currentParagraphIndex: 0,
      currentPreviewText: '',
      currentWords: const [],
      currentWordIndex: -1,
    );
  }

  /// Skip to next paragraph
  Future<void> skipForward() async {
    if (state.currentParagraphIndex < state.paragraphs.length - 1) {
      // Capture playing state BEFORE stopping
      final wasActive = state.isPlaying || state.isPaused;
      _resumeNeedsResynthesis = false;
      _resetTrackingState(clearPreview: true);
      await _service.stop();
      state = state.copyWith(
        currentParagraphIndex: state.currentParagraphIndex + 1,
        playbackState: TtsPlaybackState.stopped,
        currentPreviewText: '',
        currentWords: const [],
        currentWordIndex: -1,
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
      _resumeNeedsResynthesis = false;
      _resetTrackingState(clearPreview: true);
      await _service.stop();
      state = state.copyWith(
        currentParagraphIndex: state.currentParagraphIndex - 1,
        playbackState: TtsPlaybackState.stopped,
        currentPreviewText: '',
        currentWords: const [],
        currentWordIndex: -1,
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

    // If currently playing, restart immediately with new voice.
    final wasPlaying = state.isPlaying;
    final wasPaused = state.isPaused;

    if (wasPlaying || wasPaused) {
      _pauseWordTracking();
      await _service.stop();
    }

    state = state.copyWith(
      currentVoice: voiceId,
      playbackState: wasPaused ? TtsPlaybackState.paused : state.playbackState,
    );

    // Restart playback with new voice when currently playing.
    if (wasPlaying && state.paragraphs.isNotEmpty) {
      await play();
    }

    // If paused, apply voice change on next resume instead of resuming stale audio.
    if (wasPaused) {
      _resumeNeedsResynthesis = true;
    }
  }

  /// Set playback speed
  void setSpeed(double speed) {
    _log.info('TTS', 'Speed changed to: ${speed}x');
    final wasPlaying = state.isPlaying;
    final wasPaused = state.isPaused;

    if (wasPlaying) {
      _pauseWordTracking();
    }

    state = state.copyWith(speed: speed);
    _service.setSpeed(speed);

    if (wasPlaying && state.currentPreviewText.isNotEmpty) {
      _startWordTracking(
        state.currentPreviewText,
        startElapsed: _elapsedBeforeTracking,
      );
    } else if (wasPaused && state.currentPreviewText.isNotEmpty) {
      final words = _extractTrackableWords(state.currentPreviewText);
      final totalMs = _estimateSentenceDurationMs(words, state.speed);
      _wordTimings = _calculateWordTimings(words, totalMs);
      state = state.copyWith(
        currentWordIndex: _wordIndexForElapsed(_elapsedBeforeTracking),
      );
    }
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
    _wordTrackingTimer?.cancel();
    _playbackWatchdogTimer?.cancel();
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
