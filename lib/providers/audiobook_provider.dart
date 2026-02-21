import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../services/storage_service.dart';
import '../services/tts_service.dart';
import 'tts_provider.dart';

/// Metadata for a generated audiobook
class Audiobook {
  final String id;
  final String title;
  final String path;
  final double durationSeconds;
  final int chunks;
  final String voice;
  final double speed;
  final DateTime createdAt;

  Audiobook({
    required this.id,
    required this.title,
    required this.path,
    required this.durationSeconds,
    required this.chunks,
    required this.voice,
    required this.speed,
    required this.createdAt,
  });

  String get durationFormatted {
    final mins = (durationSeconds / 60).floor();
    final secs = (durationSeconds % 60).floor();
    return mins > 0 ? '${mins}m ${secs}s' : '${secs}s';
  }

  double get sizeMb {
    final file = File(path);
    if (file.existsSync()) {
      return file.lengthSync() / (1024 * 1024);
    }
    return 0;
  }

  bool get exists => File(path).existsSync();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'path': path,
    'durationSeconds': durationSeconds,
    'chunks': chunks,
    'voice': voice,
    'speed': speed,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Audiobook.fromJson(Map<String, dynamic> json) => Audiobook(
    id: json['id'] as String,
    title: json['title'] as String,
    path: json['path'] as String,
    durationSeconds: (json['durationSeconds'] as num).toDouble(),
    chunks: json['chunks'] as int,
    voice: json['voice'] as String,
    speed: (json['speed'] as num).toDouble(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// State for audiobook playback
class AudiobookPlaybackState {
  final String? playingId;
  final bool isPlaying;
  final bool isPaused;
  final Duration position;
  final Duration duration;

  const AudiobookPlaybackState({
    this.playingId,
    this.isPlaying = false,
    this.isPaused = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  AudiobookPlaybackState copyWith({
    String? playingId,
    bool? isPlaying,
    bool? isPaused,
    Duration? position,
    Duration? duration,
  }) => AudiobookPlaybackState(
    playingId: playingId ?? this.playingId,
    isPlaying: isPlaying ?? this.isPlaying,
    isPaused: isPaused ?? this.isPaused,
    position: position ?? this.position,
    duration: duration ?? this.duration,
  );
}

/// Provider for audiobook list
final audiobooksProvider =
    StateNotifierProvider<AudiobooksNotifier, List<Audiobook>>((ref) {
      return AudiobooksNotifier();
    });

/// Provider for audiobook generation jobs.
final audiobookJobsProvider =
    StateNotifierProvider<AudiobookJobsNotifier, List<AudiobookJob>>((ref) {
      return AudiobookJobsNotifier(ref);
    });

/// Provider for audiobook playback state
final audiobookPlaybackProvider =
    StateNotifierProvider<AudiobookPlaybackNotifier, AudiobookPlaybackState>((
      ref,
    ) {
      return AudiobookPlaybackNotifier();
    });

enum AudiobookJobStatus { queued, running, completed, failed, cancelled }

class AudiobookJob {
  final String id;
  final String title;
  final List<String> chunks;
  final String voice;
  final double speed;
  final String outputPath;
  final AudiobookJobStatus status;
  final int currentChunk;
  final int totalChunks;
  final double progress;
  final String message;
  final String? errorMessage;
  final String? resultPath;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  const AudiobookJob({
    required this.id,
    required this.title,
    required this.chunks,
    required this.voice,
    required this.speed,
    required this.outputPath,
    required this.status,
    required this.currentChunk,
    required this.totalChunks,
    required this.progress,
    required this.message,
    required this.createdAt,
    this.errorMessage,
    this.resultPath,
    this.startedAt,
    this.finishedAt,
  });

  AudiobookJob copyWith({
    String? id,
    String? title,
    List<String>? chunks,
    String? voice,
    double? speed,
    String? outputPath,
    AudiobookJobStatus? status,
    int? currentChunk,
    int? totalChunks,
    double? progress,
    String? message,
    String? errorMessage,
    String? resultPath,
    bool clearErrorMessage = false,
    bool clearResultPath = false,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    return AudiobookJob(
      id: id ?? this.id,
      title: title ?? this.title,
      chunks: chunks ?? this.chunks,
      voice: voice ?? this.voice,
      speed: speed ?? this.speed,
      outputPath: outputPath ?? this.outputPath,
      status: status ?? this.status,
      currentChunk: currentChunk ?? this.currentChunk,
      totalChunks: totalChunks ?? this.totalChunks,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      resultPath: clearResultPath ? null : (resultPath ?? this.resultPath),
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
    );
  }

  bool get isTerminal =>
      status == AudiobookJobStatus.completed ||
      status == AudiobookJobStatus.failed ||
      status == AudiobookJobStatus.cancelled;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'chunks': chunks,
    'voice': voice,
    'speed': speed,
    'outputPath': outputPath,
    'status': status.name,
    'currentChunk': currentChunk,
    'totalChunks': totalChunks,
    'progress': progress,
    'message': message,
    'errorMessage': errorMessage,
    'resultPath': resultPath,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
  };

  factory AudiobookJob.fromJson(Map<String, dynamic> json) {
    AudiobookJobStatus status = AudiobookJobStatus.queued;
    final statusText = json['status'] as String?;
    if (statusText != null) {
      for (final value in AudiobookJobStatus.values) {
        if (value.name == statusText) {
          status = value;
          break;
        }
      }
    }

    return AudiobookJob(
      id: json['id'] as String,
      title: json['title'] as String,
      chunks: (json['chunks'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      voice: json['voice'] as String,
      speed: (json['speed'] as num).toDouble(),
      outputPath: json['outputPath'] as String,
      status: status,
      currentChunk: (json['currentChunk'] as num?)?.toInt() ?? 0,
      totalChunks: (json['totalChunks'] as num?)?.toInt() ?? 0,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      message: json['message'] as String? ?? '',
      errorMessage: json['errorMessage'] as String?,
      resultPath: json['resultPath'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      startedAt: (json['startedAt'] as String?) != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      finishedAt: (json['finishedAt'] as String?) != null
          ? DateTime.parse(json['finishedAt'] as String)
          : null,
    );
  }
}

/// Get the audiobooks directory
Future<Directory> getAudiobooksDirectory() async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final dir = Directory(p.join(home, 'Documents', 'Mayari Audiobooks'));
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  return dir;
}

/// Notifier for managing audiobook list
class AudiobooksNotifier extends StateNotifier<List<Audiobook>> {
  static const String _storageKey = 'audiobooks';

  AudiobooksNotifier() : super([]) {
    _loadAudiobooks();
  }

  Future<void> _loadAudiobooks() async {
    try {
      final storage = StorageService();
      final data = await storage.loadJson(_storageKey);
      if (data != null && data is List) {
        final books = data
            .map((e) => Audiobook.fromJson(e as Map<String, dynamic>))
            .where((b) => b.exists) // Only keep existing files
            .toList();
        books.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        ); // Newest first
        state = books;
      }
    } catch (e) {
      debugPrint('Error loading audiobooks: $e');
    }
  }

  Future<void> _saveAudiobooks() async {
    try {
      final storage = StorageService();
      await storage.saveJson(
        _storageKey,
        state.map((b) => b.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving audiobooks: $e');
    }
  }

  Future<void> addAudiobook(Audiobook book) async {
    state = [book, ...state];
    await _saveAudiobooks();
  }

  Future<void> importBundledExamples(List<Audiobook> books) async {
    if (books.isEmpty) return;
    final existingPaths = state.map((b) => b.path).toSet();
    final additions = <Audiobook>[];
    for (final book in books) {
      if (existingPaths.contains(book.path)) continue;
      if (!File(book.path).existsSync()) continue;
      additions.add(book);
      existingPaths.add(book.path);
    }
    if (additions.isEmpty) return;
    state = [...additions, ...state]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _saveAudiobooks();
  }

  Future<void> deleteAudiobook(String id) async {
    final book = state.firstWhere(
      (b) => b.id == id,
      orElse: () => throw Exception('Not found'),
    );

    // Delete the file
    final file = File(book.path);
    if (file.existsSync()) {
      await file.delete();
    }

    state = state.where((b) => b.id != id).toList();
    await _saveAudiobooks();
  }

  Future<void> refresh() async {
    await _loadAudiobooks();
  }

  /// Recover audiobooks from completed jobs that have files but no audiobook entry
  Future<int> recoverFromJobs(List<AudiobookJob> jobs) async {
    int recovered = 0;
    final existingPaths = state.map((b) => b.path).toSet();

    for (final job in jobs) {
      if (job.status != AudiobookJobStatus.completed) continue;
      if (job.resultPath == null) continue;
      if (existingPaths.contains(job.resultPath)) continue;

      final file = File(job.resultPath!);
      if (!file.existsSync()) continue;

      // Try to get duration from file size (approximate: ~176KB per second for WAV)
      final fileSize = file.lengthSync();
      final estimatedDuration = fileSize / 176400.0; // 44100 Hz * 2 bytes * 2 channels

      final audiobook = Audiobook(
        id: const Uuid().v4(),
        title: job.title,
        path: job.resultPath!,
        durationSeconds: estimatedDuration,
        chunks: job.totalChunks,
        voice: job.voice,
        speed: job.speed,
        createdAt: job.finishedAt ?? job.createdAt,
      );

      state = [audiobook, ...state];
      existingPaths.add(job.resultPath!);
      recovered++;
    }

    if (recovered > 0) {
      state.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _saveAudiobooks();
    }

    return recovered;
  }
}

class AudiobookJobsNotifier extends StateNotifier<List<AudiobookJob>> {
  static const String _storageKey = 'audiobookJobs';

  final Ref _ref;
  final StorageService _storage = StorageService();
  StreamSubscription<AudiobookProgress>? _progressSubscription;
  bool _isProcessing = false;
  bool _isDisposed = false;

  AudiobookJobsNotifier(this._ref) : super(const []) {
    _loadJobs();
  }

  Future<void> _loadJobs() async {
    try {
      final data = await _storage.loadJson(_storageKey);
      if (data is! List) return;

      final loaded = data
          .map((e) => AudiobookJob.fromJson(e as Map<String, dynamic>))
          .toList();

      // Recover any interrupted running jobs as failed.
      final recovered =
          loaded
              .map(
                (job) => job.status == AudiobookJobStatus.running
                    ? job.copyWith(
                        status: AudiobookJobStatus.failed,
                        progress: 0,
                        message: 'Interrupted before completion',
                        errorMessage: 'App was closed during generation',
                        finishedAt: DateTime.now(),
                      )
                    : job,
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      state = recovered;
      await _saveJobs();

      // Recover any audiobooks from completed jobs that might be missing
      final audiobooksNotifier = _ref.read(audiobooksProvider.notifier);
      final recoveredCount = await audiobooksNotifier.recoverFromJobs(state);
      if (recoveredCount > 0) {
        debugPrint('Recovered $recoveredCount audiobooks from completed jobs');
      }

      unawaited(_processQueue());
    } catch (e) {
      debugPrint('Error loading audiobook jobs: $e');
    }
  }

  Future<void> _saveJobs() async {
    try {
      await _storage.saveJson(
        _storageKey,
        state.map((job) => job.toJson()).toList(),
      );
    } catch (e) {
      debugPrint('Error saving audiobook jobs: $e');
    }
  }

  Future<String> _buildOutputPath(String title) async {
    final dir = await getAudiobooksDirectory();
    final safeTitle = title
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    final baseName = safeTitle.isEmpty ? 'audiobook' : safeTitle;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '${baseName}_$timestamp.wav');
  }

  List<String> _prepareChunksForGeneration(List<String> chunks) {
    const targetChunkChars = 180;
    const maxChunks = 1200;
    final prepared = <String>[];

    for (final raw in chunks) {
      final normalized = raw
          .replaceAll('\u00A0', ' ')
          .replaceAll('\r', '\n')
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      if (normalized.isEmpty) continue;

      final sentences = normalized
          .split(RegExp(r'(?<=[.!?])\s+|\n+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (sentences.isEmpty) {
        _splitLongChunk(normalized, targetChunkChars, prepared);
        continue;
      }

      final current = StringBuffer();
      for (final sentence in sentences) {
        final candidate = current.isEmpty
            ? sentence
            : '${current.toString()} $sentence';
        if (candidate.length <= targetChunkChars) {
          current
            ..clear()
            ..write(candidate);
          continue;
        }

        if (current.isNotEmpty) {
          prepared.add(current.toString().trim());
          current.clear();
        }

        if (sentence.length <= targetChunkChars) {
          current.write(sentence);
        } else {
          _splitLongChunk(sentence, targetChunkChars, prepared);
        }
      }

      if (current.isNotEmpty) {
        prepared.add(current.toString().trim());
      }
    }

    final deduped = <String>[];
    String? previousNormalized;
    for (final chunk in prepared) {
      final normalized = chunk
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (normalized.isEmpty) continue;
      if (normalized == previousNormalized) continue;
      deduped.add(chunk.trim());
      previousNormalized = normalized;
      if (deduped.length >= maxChunks) break;
    }

    return deduped;
  }

  void _splitLongChunk(String chunk, int targetChunkChars, List<String> out) {
    final words = chunk
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return;

    final current = StringBuffer();
    for (final word in words) {
      final candidate = current.isEmpty ? word : '${current.toString()} $word';
      if (candidate.length <= targetChunkChars) {
        current
          ..clear()
          ..write(candidate);
        continue;
      }
      if (current.isNotEmpty) {
        out.add(current.toString().trim());
        current.clear();
      }
      if (word.length > targetChunkChars) {
        var start = 0;
        while (start < word.length) {
          final end = (start + targetChunkChars).clamp(0, word.length).toInt();
          out.add(word.substring(start, end).trim());
          start = end;
        }
      } else {
        current.write(word);
      }
    }
    if (current.isNotEmpty) {
      out.add(current.toString().trim());
    }
  }

  Future<void> enqueue({
    required String title,
    required List<String> chunks,
    required String voice,
    required double speed,
  }) async {
    final normalizedChunks = chunks
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();
    final preparedChunks = _prepareChunksForGeneration(normalizedChunks);
    if (preparedChunks.isEmpty) return;

    final outputPath = await _buildOutputPath(title);
    final job = AudiobookJob(
      id: const Uuid().v4(),
      title: title,
      chunks: preparedChunks,
      voice: voice,
      speed: speed,
      outputPath: outputPath,
      status: AudiobookJobStatus.queued,
      currentChunk: 0,
      totalChunks: preparedChunks.length,
      progress: 0,
      message: 'Queued',
      createdAt: DateTime.now(),
    );

    state = [job, ...state];
    await _saveJobs();
    unawaited(_processQueue());
  }

  Future<void> retry(String jobId) async {
    final job = _findJob(jobId);
    if (job == null) return;
    if (job.status != AudiobookJobStatus.failed &&
        job.status != AudiobookJobStatus.cancelled) {
      return;
    }

    final freshPath = await _buildOutputPath(job.title);
    final preparedChunks = _prepareChunksForGeneration(job.chunks);
    if (preparedChunks.isEmpty) {
      await _markFailed(job.id, 'No usable text chunks after preprocessing');
      return;
    }
    _updateJob(
      jobId,
      (j) => j.copyWith(
        status: AudiobookJobStatus.queued,
        progress: 0,
        message: 'Queued',
        clearErrorMessage: true,
        clearResultPath: true,
        chunks: preparedChunks,
        outputPath: freshPath,
        currentChunk: 0,
        totalChunks: preparedChunks.length,
        startedAt: null,
        finishedAt: null,
      ),
    );
    await _saveJobs();
    unawaited(_processQueue());
  }

  Future<void> cancelQueued(String jobId) async {
    final job = _findJob(jobId);
    if (job == null || job.status != AudiobookJobStatus.queued) return;
    _updateJob(
      jobId,
      (j) => j.copyWith(
        status: AudiobookJobStatus.cancelled,
        message: 'Cancelled',
        finishedAt: DateTime.now(),
      ),
    );
    await _saveJobs();
  }

  Future<void> remove(String jobId) async {
    final job = _findJob(jobId);
    if (job == null || job.status == AudiobookJobStatus.running) return;
    state = state.where((j) => j.id != jobId).toList();
    await _saveJobs();
  }

  AudiobookJob? _nextQueuedJob() {
    AudiobookJob? selected;
    for (final job in state) {
      if (job.status != AudiobookJobStatus.queued) continue;
      if (selected == null || job.createdAt.isBefore(selected.createdAt)) {
        selected = job;
      }
    }
    return selected;
  }

  AudiobookJob? _findJob(String jobId) {
    for (final job in state) {
      if (job.id == jobId) return job;
    }
    return null;
  }

  void _updateJob(String id, AudiobookJob Function(AudiobookJob) update) {
    state = [
      for (final job in state)
        if (job.id == id) update(job) else job,
    ];
  }

  Future<void> _markFailed(String id, String message) async {
    _updateJob(
      id,
      (job) => job.copyWith(
        status: AudiobookJobStatus.failed,
        message: 'Failed',
        errorMessage: message,
        progress: 0,
        finishedAt: DateTime.now(),
      ),
    );
    await _saveJobs();
  }

  Future<void> _runJob(AudiobookJob job) async {
    final service = _ref.read(ttsServiceProvider);

    _updateJob(
      job.id,
      (j) => j.copyWith(
        status: AudiobookJobStatus.running,
        message: 'Preparing audio...',
        clearErrorMessage: true,
        startedAt: DateTime.now(),
        finishedAt: null,
        currentChunk: 0,
        progress: 0,
      ),
    );
    await _saveJobs();

    _progressSubscription?.cancel();
    _progressSubscription = service.audiobookProgress.listen((progress) {
      if (_isDisposed) return;
      _updateJob(
        job.id,
        (j) => j.copyWith(
          currentChunk: progress.currentChunk,
          totalChunks: progress.totalChunks,
          progress: progress.progress.clamp(0, 1).toDouble(),
          message: progress.status,
        ),
      );
    });

    try {
      final result = await service.generateAudiobook(
        chunks: job.chunks,
        outputPath: job.outputPath,
        title: job.title,
        voice: job.voice,
        speed: job.speed,
      );

      await _progressSubscription?.cancel();
      _progressSubscription = null;

      if (result == null) {
        final details =
            service.lastAudiobookError ?? 'Generator returned no result';
        await _markFailed(job.id, details);
        return;
      }

      final outputFile = File(result.path);
      final outputExists = outputFile.existsSync();
      final outputSize = outputExists ? outputFile.lengthSync() : 0;
      if (!outputExists || outputSize < 1024 || result.duration <= 0.2) {
        await _markFailed(job.id, 'Audio output is empty or inaudible');
        return;
      }

      final audiobook = Audiobook(
        id: const Uuid().v4(),
        title: job.title,
        path: result.path,
        durationSeconds: result.duration,
        chunks: result.chunks,
        voice: job.voice,
        speed: job.speed,
        createdAt: DateTime.now(),
      );
      await _ref.read(audiobooksProvider.notifier).addAudiobook(audiobook);

      _updateJob(
        job.id,
        (j) => j.copyWith(
          status: AudiobookJobStatus.completed,
          progress: 1,
          message: 'Completed',
          clearErrorMessage: true,
          resultPath: result.path,
          currentChunk: result.chunks,
          totalChunks: result.chunks,
          finishedAt: DateTime.now(),
          chunks: const [],
        ),
      );
      await _saveJobs();
    } catch (e) {
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      await _markFailed(job.id, e.toString());
    }
  }

  Future<void> _processQueue() async {
    if (_isDisposed || _isProcessing) return;
    _isProcessing = true;
    try {
      while (!_isDisposed) {
        final next = _nextQueuedJob();
        if (next == null) break;
        await _runJob(next);
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _progressSubscription?.cancel();
    super.dispose();
  }
}

/// Notifier for audiobook playback
class AudiobookPlaybackNotifier extends StateNotifier<AudiobookPlaybackState> {
  final AudioPlayer _player = AudioPlayer();

  AudiobookPlaybackNotifier() : super(const AudiobookPlaybackState()) {
    _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        // Reset full state when playback completes naturally
        state = const AudiobookPlaybackState();
      }
    });

    _player.positionStream.listen((position) {
      // Only update position if we have an active playback
      if (state.playingId != null) {
        state = state.copyWith(position: position);
      }
    });

    _player.durationStream.listen((duration) {
      if (duration != null && state.playingId != null) {
        state = state.copyWith(duration: duration);
      }
    });
  }

  Future<void> play(Audiobook book) async {
    debugPrint('AudiobookPlayback: play() called for "${book.title}" (id: ${book.id})');
    try {
      // Stop any existing playback first to avoid stream conflicts
      if (state.playingId != null) {
        debugPrint('AudiobookPlayback: stopping previous playback');
        await _player.stop();
      }
      debugPrint('AudiobookPlayback: setting file path: ${book.path}');
      await _player.setFilePath(book.path);
      debugPrint('AudiobookPlayback: starting playback');
      await _player.play();
      state = AudiobookPlaybackState(
        playingId: book.id,
        isPlaying: true,
        isPaused: false,
      );
      debugPrint('AudiobookPlayback: state updated - playingId=${state.playingId}, isPlaying=${state.isPlaying}');
    } catch (e) {
      debugPrint('AudiobookPlayback: Error playing audiobook: $e');
      state = const AudiobookPlaybackState();
    }
  }

  Future<void> pause() async {
    await _player.pause();
    state = state.copyWith(isPlaying: false, isPaused: true);
  }

  Future<void> resume() async {
    await _player.play();
    state = state.copyWith(isPlaying: true, isPaused: false);
  }

  Future<void> stop() async {
    debugPrint('AudiobookPlayback: stop() called, current state: playingId=${state.playingId}, isPlaying=${state.isPlaying}, isPaused=${state.isPaused}');
    await _player.stop();
    state = const AudiobookPlaybackState();
    debugPrint('AudiobookPlayback: stop() complete, state reset');
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
