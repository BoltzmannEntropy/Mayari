import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/tts_service.dart';
import 'tts_provider.dart';

/// State of the TTS model download
enum ModelDownloadState {
  checking,      // Initial state, checking if model exists
  notDownloaded, // Model not present
  downloading,   // Download in progress
  ready,         // Model downloaded and loadable
  error,         // Download or load failed
}

/// Status of the model download with progress info
class ModelDownloadStatus {
  final ModelDownloadState state;
  final double progress;
  final String? errorMessage;
  final String? statusMessage;

  const ModelDownloadStatus({
    required this.state,
    this.progress = 0.0,
    this.errorMessage,
    this.statusMessage,
  });

  ModelDownloadStatus copyWith({
    ModelDownloadState? state,
    double? progress,
    String? errorMessage,
    String? statusMessage,
  }) {
    return ModelDownloadStatus(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      statusMessage: statusMessage,
    );
  }

  bool get isReady => state == ModelDownloadState.ready;
  bool get isDownloading => state == ModelDownloadState.downloading;
  bool get needsDownload => state == ModelDownloadState.notDownloaded;
  bool get hasError => state == ModelDownloadState.error;
}

/// Notifier for model download state management
class ModelDownloadNotifier extends StateNotifier<ModelDownloadStatus> {
  final TtsService _service;
  StreamSubscription<double>? _progressSubscription;

  ModelDownloadNotifier(this._service)
      : super(const ModelDownloadStatus(state: ModelDownloadState.checking)) {
    _checkModelStatus();
  }

  /// Check if model is already downloaded
  Future<void> _checkModelStatus() async {
    try {
      final isDownloaded = await _service.isModelDownloaded();
      if (isDownloaded) {
        // Try to verify model can be loaded
        final status = await _service.getModelStatus();
        if (status['loaded'] == true || status['available'] == true) {
          state = const ModelDownloadStatus(
            state: ModelDownloadState.ready,
            statusMessage: 'TTS model ready',
          );
        } else {
          // Model files exist, should be loadable
          state = const ModelDownloadStatus(
            state: ModelDownloadState.ready,
            statusMessage: 'TTS model available',
          );
        }
      } else {
        state = const ModelDownloadStatus(
          state: ModelDownloadState.notDownloaded,
          statusMessage: 'TTS model not downloaded',
        );
      }
    } catch (e) {
      debugPrint('Model status check failed: $e');
      state = ModelDownloadStatus(
        state: ModelDownloadState.error,
        errorMessage: 'Failed to check model status: $e',
      );
    }
  }

  /// Start downloading the model
  Future<bool> startDownload() async {
    if (state.isDownloading) {
      return false;
    }

    state = const ModelDownloadStatus(
      state: ModelDownloadState.downloading,
      progress: 0.0,
      statusMessage: 'Starting download...',
    );

    // Subscribe to progress updates
    _progressSubscription?.cancel();
    _progressSubscription = _service.downloadProgress.listen((progress) {
      final message = progress < 0.9
          ? 'Downloading model... ${(progress * 100).toInt()}%'
          : 'Downloading voices... ${(progress * 100).toInt()}%';
      state = ModelDownloadStatus(
        state: ModelDownloadState.downloading,
        progress: progress,
        statusMessage: message,
      );
    });

    try {
      final success = await _service.downloadModel(
        onProgress: (progress) {
          // Progress is also handled by stream subscription
        },
      );

      _progressSubscription?.cancel();

      if (success) {
        state = const ModelDownloadStatus(
          state: ModelDownloadState.ready,
          progress: 1.0,
          statusMessage: 'Download complete!',
        );
        return true;
      } else {
        state = const ModelDownloadStatus(
          state: ModelDownloadState.error,
          errorMessage: 'Download failed. Please try again.',
        );
        return false;
      }
    } catch (e) {
      _progressSubscription?.cancel();
      debugPrint('Model download failed: $e');
      state = ModelDownloadStatus(
        state: ModelDownloadState.error,
        errorMessage: 'Download failed: $e',
      );
      return false;
    }
  }

  /// Cancel ongoing download (if possible)
  void cancelDownload() {
    _progressSubscription?.cancel();
    state = const ModelDownloadStatus(
      state: ModelDownloadState.notDownloaded,
      statusMessage: 'Download cancelled',
    );
  }

  /// Retry after error
  Future<void> retry() async {
    await _checkModelStatus();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for model download status
final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadNotifier, ModelDownloadStatus>((ref) {
  final service = ref.watch(ttsServiceProvider);
  return ModelDownloadNotifier(service);
});

/// Simple provider to check if TTS is ready (convenience)
final isTtsReadyProvider = Provider<bool>((ref) {
  final status = ref.watch(modelDownloadProvider);
  return status.isReady;
});
