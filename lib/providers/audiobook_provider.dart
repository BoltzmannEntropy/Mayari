import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../services/audiobook_chunking.dart';
import '../services/log_service.dart';
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

const String outputPathsStorageKey = 'output_paths';
const String audiobooksOutputDirKey = 'audiobooks_dir';
const String exportsOutputDirKey = 'exports_dir';

enum AudiobookJobStatus { queued, running, completed, failed, cancelled }

enum AudiobookJobType { generation, optimizedExport }

class AudiobookJob {
  final String id;
  final String title;
  final AudiobookJobType jobType;
  final List<String> chunks;
  final String voice;
  final double speed;
  final String outputPath;
  final String outputFormat;
  final String? sourcePath;
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
    required this.jobType,
    required this.chunks,
    required this.voice,
    required this.speed,
    required this.outputPath,
    required this.outputFormat,
    required this.status,
    required this.currentChunk,
    required this.totalChunks,
    required this.progress,
    required this.message,
    required this.createdAt,
    this.sourcePath,
    this.errorMessage,
    this.resultPath,
    this.startedAt,
    this.finishedAt,
  });

  AudiobookJob copyWith({
    String? id,
    String? title,
    AudiobookJobType? jobType,
    List<String>? chunks,
    String? voice,
    double? speed,
    String? outputPath,
    String? outputFormat,
    String? sourcePath,
    bool clearSourcePath = false,
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
      jobType: jobType ?? this.jobType,
      chunks: chunks ?? this.chunks,
      voice: voice ?? this.voice,
      speed: speed ?? this.speed,
      outputPath: outputPath ?? this.outputPath,
      outputFormat: outputFormat ?? this.outputFormat,
      sourcePath: clearSourcePath ? null : (sourcePath ?? this.sourcePath),
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
    'jobType': jobType.name,
    'chunks': chunks,
    'voice': voice,
    'speed': speed,
    'outputPath': outputPath,
    'outputFormat': outputFormat,
    'sourcePath': sourcePath,
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

    AudiobookJobType jobType = AudiobookJobType.generation;
    final jobTypeText = json['jobType'] as String?;
    if (jobTypeText != null) {
      for (final value in AudiobookJobType.values) {
        if (value.name == jobTypeText) {
          jobType = value;
          break;
        }
      }
    }

    return AudiobookJob(
      id: json['id'] as String,
      title: json['title'] as String,
      jobType: jobType,
      chunks: (json['chunks'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      voice: (json['voice'] as String?) ?? 'bf_emma',
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      outputPath: json['outputPath'] as String,
      outputFormat: (json['outputFormat'] as String?) ?? 'wav',
      sourcePath: json['sourcePath'] as String?,
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
  return _resolveOutputDirectory(
    configKey: audiobooksOutputDirKey,
    fallbackSegments: ['Documents', 'Mayari Audiobooks'],
  );
}

/// Get the default optimized-export directory.
Future<Directory> getAudiobookExportsDirectory() async {
  return _resolveOutputDirectory(
    configKey: exportsOutputDirKey,
    fallbackSegments: ['Documents', 'Mayari Exports'],
  );
}

Future<Map<String, String>> getConfiguredOutputDirectories() async {
  final data = await _loadOutputPathConfig();
  return {
    audiobooksOutputDirKey: (data[audiobooksOutputDirKey] as String?) ?? '',
    exportsOutputDirKey: (data[exportsOutputDirKey] as String?) ?? '',
  };
}

Future<void> setConfiguredOutputDirectory(String key, String value) async {
  final storage = StorageService();
  final data = await _loadOutputPathConfig();
  if (value.trim().isEmpty) {
    data.remove(key);
  } else {
    data[key] = value.trim();
  }
  await storage.saveJson(outputPathsStorageKey, data);
}

Future<Directory> _resolveOutputDirectory({
  required String configKey,
  required List<String> fallbackSegments,
}) async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final config = await _loadOutputPathConfig();
  final configuredPath = (config[configKey] as String?)?.trim();
  final dir = configuredPath != null && configuredPath.isNotEmpty
      ? Directory(configuredPath)
      : Directory(p.joinAll([home, ...fallbackSegments]));
  if (!dir.existsSync()) {
    await dir.create(recursive: true);
  }
  return dir;
}

Future<Map<String, dynamic>> _loadOutputPathConfig() async {
  final storage = StorageService();
  final loaded = await storage.loadJson(outputPathsStorageKey);
  if (loaded is Map<String, dynamic>) return Map<String, dynamic>.from(loaded);
  if (loaded is Map) {
    return loaded.map((key, value) => MapEntry(key.toString(), value));
  }
  return {};
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
    state = [...additions, ...state]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
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
      if (job.jobType != AudiobookJobType.generation) continue;
      if (job.status != AudiobookJobStatus.completed) continue;
      if (job.resultPath == null) continue;
      if (existingPaths.contains(job.resultPath)) continue;

      final file = File(job.resultPath!);
      if (!file.existsSync()) continue;

      // Try to get duration from file size (approximate: ~176KB per second for WAV)
      final fileSize = file.lengthSync();
      final estimatedDuration =
          fileSize / 176400.0; // 44100 Hz * 2 bytes * 2 channels

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

  LogService get _log => _ref.read(logServiceProvider.notifier);

  String _jobTypeLabel(AudiobookJobType type) {
    switch (type) {
      case AudiobookJobType.generation:
        return 'generation';
      case AudiobookJobType.optimizedExport:
        return 'optimized export';
    }
  }

  void _logJobAction(
    String action,
    AudiobookJob job, {
    String? details,
    bool asError = false,
  }) {
    final detailSuffix = details == null || details.isEmpty
        ? ''
        : ' ($details)';
    final message =
        '${job.id}: ${_jobTypeLabel(job.jobType)} $action - ${job.title}$detailSuffix';
    if (asError) {
      _log.error('Jobs', message);
    } else {
      _log.info('Jobs', message);
    }
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
                        errorMessage:
                            'App was closed during ${_jobTypeLabel(job.jobType)}',
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
      final interruptedCount = recovered
          .where(
            (job) =>
                job.status == AudiobookJobStatus.failed &&
                job.errorMessage ==
                    'App was closed during ${_jobTypeLabel(job.jobType)}',
          )
          .length;
      if (interruptedCount > 0) {
        _log.warning(
          'Jobs',
          'Recovered $interruptedCount interrupted jobs from previous session',
        );
      }

      unawaited(_processQueue());
    } catch (e) {
      debugPrint('Error loading audiobook jobs: $e');
      _log.error('Jobs', 'Failed to load jobs: $e');
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
      _log.error('Jobs', 'Failed to save jobs: $e');
    }
  }

  String _safeTitle(String title) {
    final safeTitle = title
        .trim()
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_');
    return safeTitle.isEmpty ? 'audiobook' : safeTitle;
  }

  Future<String> _buildGenerationOutputPath(String title) async {
    final dir = await getAudiobooksDirectory();
    final baseName = _safeTitle(title);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '${baseName}_$timestamp.wav');
  }

  Future<String> _buildOptimizedExportPath(String title) async {
    final dir = await getAudiobookExportsDirectory();
    final baseName = _safeTitle(title);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return p.join(dir.path, '${baseName}_optimized_$timestamp.m4b');
  }

  List<String> _prepareChunksForGeneration(List<String> chunks) {
    return AudiobookChunking.prepareChunksForGeneration(chunks);
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

    final outputPath = await _buildGenerationOutputPath(title);
    final job = AudiobookJob(
      id: const Uuid().v4(),
      title: title,
      jobType: AudiobookJobType.generation,
      chunks: preparedChunks,
      voice: voice,
      speed: speed,
      outputPath: outputPath,
      outputFormat: 'wav',
      status: AudiobookJobStatus.queued,
      currentChunk: 0,
      totalChunks: preparedChunks.length,
      progress: 0,
      message: 'Queued generation',
      createdAt: DateTime.now(),
    );

    state = [job, ...state];
    await _saveJobs();
    _logJobAction('queued', job);
    unawaited(_processQueue());
  }

  Future<bool> enqueueOptimizedExport({
    required String title,
    required String sourcePath,
  }) async {
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      _log.error('Jobs', 'Optimized export source not found: $sourcePath');
      return false;
    }

    final outputPath = await _buildOptimizedExportPath(title);
    final job = AudiobookJob(
      id: const Uuid().v4(),
      title: title,
      jobType: AudiobookJobType.optimizedExport,
      chunks: const [],
      voice: 'n/a',
      speed: 1.0,
      outputPath: outputPath,
      outputFormat: 'm4b',
      sourcePath: sourcePath,
      status: AudiobookJobStatus.queued,
      currentChunk: 0,
      totalChunks: 1,
      progress: 0,
      message: 'Queued optimized export',
      createdAt: DateTime.now(),
    );

    state = [job, ...state];
    await _saveJobs();
    _logJobAction('queued', job, details: 'target=${job.outputPath}');
    unawaited(_processQueue());
    return true;
  }

  Future<void> retry(String jobId) async {
    final job = _findJob(jobId);
    if (job == null) return;
    if (job.status != AudiobookJobStatus.failed &&
        job.status != AudiobookJobStatus.cancelled) {
      return;
    }

    if (job.jobType == AudiobookJobType.generation) {
      final freshPath = await _buildGenerationOutputPath(job.title);
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
          message: 'Queued generation',
          clearErrorMessage: true,
          clearResultPath: true,
          chunks: preparedChunks,
          outputPath: freshPath,
          outputFormat: 'wav',
          currentChunk: 0,
          totalChunks: preparedChunks.length,
          startedAt: null,
          finishedAt: null,
        ),
      );
    } else {
      final source = job.sourcePath;
      if (source == null || source.isEmpty || !File(source).existsSync()) {
        await _markFailed(job.id, 'Missing source file for optimized export');
        return;
      }
      final freshPath = await _buildOptimizedExportPath(job.title);
      _updateJob(
        jobId,
        (j) => j.copyWith(
          status: AudiobookJobStatus.queued,
          progress: 0,
          message: 'Queued optimized export',
          clearErrorMessage: true,
          clearResultPath: true,
          outputPath: freshPath,
          outputFormat: 'm4b',
          currentChunk: 0,
          totalChunks: 1,
          startedAt: null,
          finishedAt: null,
        ),
      );
    }
    await _saveJobs();
    final queuedJob = _findJob(jobId);
    if (queuedJob != null) {
      _logJobAction('re-queued', queuedJob);
    }
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
    final cancelled = _findJob(jobId);
    if (cancelled != null) {
      _logJobAction('cancelled', cancelled);
    }
  }

  Future<void> remove(String jobId) async {
    final job = _findJob(jobId);
    if (job == null || job.status == AudiobookJobStatus.running) return;
    state = state.where((j) => j.id != jobId).toList();
    await _saveJobs();
    _logJobAction('removed', job);
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
    final failed = _findJob(id);
    if (failed != null) {
      _logJobAction('failed', failed, details: message, asError: true);
    }
  }

  Future<void> _runGenerationJob(AudiobookJob job) async {
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
    final running = _findJob(job.id);
    if (running != null) {
      _logJobAction('started', running);
    }

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
          outputFormat: result.format,
          currentChunk: result.chunks,
          totalChunks: result.chunks,
          finishedAt: DateTime.now(),
          chunks: const [],
        ),
      );
      await _saveJobs();
      final completed = _findJob(job.id);
      if (completed != null) {
        _logJobAction('completed', completed, details: result.path);
      }
    } catch (e) {
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      await _markFailed(job.id, e.toString());
    }
  }

  Future<void> _runOptimizedExportJob(AudiobookJob job) async {
    _updateJob(
      job.id,
      (j) => j.copyWith(
        status: AudiobookJobStatus.running,
        message: 'Preparing optimized export...',
        clearErrorMessage: true,
        startedAt: DateTime.now(),
        finishedAt: null,
        currentChunk: 0,
        totalChunks: 1,
        progress: 0,
      ),
    );
    await _saveJobs();
    final running = _findJob(job.id);
    if (running != null) {
      _logJobAction('started', running, details: 'target=${job.outputPath}');
    }

    final sourcePath = job.sourcePath;
    if (sourcePath == null || sourcePath.isEmpty) {
      await _markFailed(job.id, 'Missing source path for optimized export');
      return;
    }

    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      await _markFailed(job.id, 'Source file not found: $sourcePath');
      return;
    }

    try {
      await File(job.outputPath).parent.create(recursive: true);

      String finalPath = job.outputPath;
      String finalFormat = job.outputFormat;
      bool usedFallback = false;

      if (!kIsWeb && Platform.isMacOS) {
        final conversion = await Process.run('afconvert', [
          '-f',
          'm4af',
          '-d',
          'aac',
          '-q',
          '127',
          sourcePath,
          job.outputPath,
        ]);
        final convertedFile = File(job.outputPath);
        if (conversion.exitCode != 0 || !convertedFile.existsSync()) {
          usedFallback = true;
        }
      } else {
        usedFallback = true;
      }

      if (usedFallback) {
        final fallbackPath = p.setExtension(job.outputPath, '.wav');
        await sourceFile.copy(fallbackPath);
        finalPath = fallbackPath;
        finalFormat = 'wav';
      }

      final exportedFile = File(finalPath);
      if (!exportedFile.existsSync() || exportedFile.lengthSync() < 1024) {
        await _markFailed(job.id, 'Optimized export output is empty');
        return;
      }

      final message = usedFallback
          ? 'Optimized export completed (WAV fallback)'
          : 'Optimized export completed';

      _updateJob(
        job.id,
        (j) => j.copyWith(
          status: AudiobookJobStatus.completed,
          progress: 1,
          message: message,
          clearErrorMessage: true,
          resultPath: finalPath,
          outputFormat: finalFormat,
          currentChunk: 1,
          totalChunks: 1,
          finishedAt: DateTime.now(),
        ),
      );
      await _saveJobs();
      final completed = _findJob(job.id);
      if (completed != null) {
        _logJobAction(
          'completed',
          completed,
          details: '$finalFormat -> $finalPath',
        );
      }
    } catch (e) {
      await _markFailed(job.id, e.toString());
    }
  }

  Future<void> _runJob(AudiobookJob job) async {
    if (job.jobType == AudiobookJobType.optimizedExport) {
      await _runOptimizedExportJob(job);
      return;
    }
    await _runGenerationJob(job);
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
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration?>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  AudiobookPlaybackNotifier() : super(const AudiobookPlaybackState()) {
    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        // Reset full state when playback completes naturally
        state = const AudiobookPlaybackState();
      }
    });

    _positionSubscription = _player.positionStream.listen((position) {
      // Only update position if we have an active playback
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

  Future<void> play(Audiobook book) async {
    debugPrint(
      'AudiobookPlayback: play() called for "${book.title}" (id: ${book.id})',
    );
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
      debugPrint(
        'AudiobookPlayback: state updated - playingId=${state.playingId}, isPlaying=${state.isPlaying}',
      );
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
    debugPrint(
      'AudiobookPlayback: stop() called, current state: playingId=${state.playingId}, isPlaying=${state.isPlaying}, isPaused=${state.isPaused}',
    );
    await _player.stop();
    state = const AudiobookPlaybackState();
    debugPrint('AudiobookPlayback: stop() complete, state reset');
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
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
