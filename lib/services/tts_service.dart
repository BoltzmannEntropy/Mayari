import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;

String _inferLanguageCodeFromVoiceId(String voiceId) {
  if (voiceId.startsWith('af_') || voiceId.startsWith('am_')) return 'en-us';
  if (voiceId.startsWith('bf_') || voiceId.startsWith('bm_')) return 'en-gb';
  if (voiceId.startsWith('ef_') || voiceId.startsWith('em_')) return 'es-es';
  if (voiceId.startsWith('ff_') || voiceId.startsWith('fm_')) return 'fr-fr';
  if (voiceId.startsWith('hf_') || voiceId.startsWith('hm_')) return 'hi-in';
  if (voiceId.startsWith('if_') || voiceId.startsWith('im_')) return 'it-it';
  if (voiceId.startsWith('jf_') || voiceId.startsWith('jm_')) return 'ja-jp';
  if (voiceId.startsWith('pf_') || voiceId.startsWith('pm_')) return 'pt-br';
  if (voiceId.startsWith('zf_') || voiceId.startsWith('zm_')) return 'zh-cn';
  return 'en-us';
}

String _languageNameForCode(String code) {
  switch (code.toLowerCase()) {
    case 'en-us':
      return 'English (US)';
    case 'en-gb':
      return 'English (UK)';
    case 'es-es':
      return 'Spanish';
    case 'fr-fr':
      return 'French';
    case 'hi-in':
      return 'Hindi';
    case 'it-it':
      return 'Italian';
    case 'ja-jp':
      return 'Japanese';
    case 'pt-br':
      return 'Brazilian Portuguese';
    case 'zh-cn':
      return 'Mandarin Chinese';
    default:
      return code;
  }
}

/// Voice metadata for Kokoro voices.
class TtsVoice {
  final String id;
  final String name;
  final String gender;
  final String grade;
  final String languageCode;
  final String languageName;
  final bool isDefault;

  const TtsVoice({
    required this.id,
    required this.name,
    required this.gender,
    required this.grade,
    required this.languageCode,
    required this.languageName,
    this.isDefault = false,
  });

  factory TtsVoice.fromJson(Map<String, dynamic> json) {
    final id = json['code'] as String;
    final languageCode =
        (json['language_code'] as String?) ?? _inferLanguageCodeFromVoiceId(id);
    return TtsVoice(
      id: id,
      name: json['name'] as String,
      gender: json['gender'] as String,
      grade: json['grade'] as String,
      languageCode: languageCode,
      languageName:
          (json['language_name'] as String?) ??
          _languageNameForCode(languageCode),
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  String get displayName => '$name ($grade)';
}

/// Available Kokoro voices (fallback if native unavailable).
const List<TtsVoice> defaultVoices = [
  // American English
  TtsVoice(
    id: 'af_alloy',
    name: 'Alloy',
    gender: 'female',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_aoede',
    name: 'Aoede',
    gender: 'female',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_bella',
    name: 'Bella',
    gender: 'female',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_heart',
    name: 'Heart',
    gender: 'female',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_jessica',
    name: 'Jessica',
    gender: 'female',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_kore',
    name: 'Kore',
    gender: 'female',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_nicole',
    name: 'Nicole',
    gender: 'female',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_nova',
    name: 'Nova',
    gender: 'female',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_river',
    name: 'River',
    gender: 'female',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_sarah',
    name: 'Sarah',
    gender: 'female',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'af_sky',
    name: 'Sky',
    gender: 'female',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'am_adam',
    name: 'Adam',
    gender: 'male',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'am_echo',
    name: 'Echo',
    gender: 'male',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'am_eric',
    name: 'Eric',
    gender: 'male',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'am_fenrir',
    name: 'Fenrir',
    gender: 'male',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'am_liam',
    name: 'Liam',
    gender: 'male',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'am_michael',
    name: 'Michael',
    gender: 'male',
    grade: 'B',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'am_onyx',
    name: 'Onyx',
    gender: 'male',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'am_puck',
    name: 'Puck',
    gender: 'male',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  TtsVoice(
    id: 'am_santa',
    name: 'Santa',
    gender: 'male',
    grade: 'C',
    languageCode: 'en-us',
    languageName: 'English (US)',
  ),
  // British English
  TtsVoice(
    id: 'bf_alice',
    name: 'Alice',
    gender: 'female',
    grade: 'D',
    languageCode: 'en-gb',
    languageName: 'English (UK)',
  ),
  TtsVoice(
    id: 'bf_emma',
    name: 'Emma',
    gender: 'female',
    grade: 'B-',
    languageCode: 'en-gb',
    languageName: 'English (UK)',
    isDefault: true,
  ),
  TtsVoice(
    id: 'bf_isabella',
    name: 'Isabella',
    gender: 'female',
    grade: 'C',
    languageCode: 'en-gb',
    languageName: 'English (UK)',
  ),
  TtsVoice(
    id: 'bf_lily',
    name: 'Lily',
    gender: 'female',
    grade: 'D',
    languageCode: 'en-gb',
    languageName: 'English (UK)',
  ),
  TtsVoice(
    id: 'bm_daniel',
    name: 'Daniel',
    gender: 'male',
    grade: 'D',
    languageCode: 'en-gb',
    languageName: 'English (UK)',
  ),
  TtsVoice(
    id: 'bm_fable',
    name: 'Fable',
    gender: 'male',
    grade: 'C',
    languageCode: 'en-gb',
    languageName: 'English (UK)',
  ),
  TtsVoice(
    id: 'bm_george',
    name: 'George',
    gender: 'male',
    grade: 'C',
    languageCode: 'en-gb',
    languageName: 'English (UK)',
  ),
  TtsVoice(
    id: 'bm_lewis',
    name: 'Lewis',
    gender: 'male',
    grade: 'D+',
    languageCode: 'en-gb',
    languageName: 'English (UK)',
  ),
  // Spanish
  TtsVoice(
    id: 'ef_dora',
    name: 'Dora',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'es-es',
    languageName: 'Spanish',
  ),
  TtsVoice(
    id: 'em_alex',
    name: 'Alex',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'es-es',
    languageName: 'Spanish',
  ),
  TtsVoice(
    id: 'em_santa',
    name: 'Santa',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'es-es',
    languageName: 'Spanish',
  ),
  // French
  TtsVoice(
    id: 'ff_siwis',
    name: 'Siwis',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'fr-fr',
    languageName: 'French',
  ),
  // Hindi
  TtsVoice(
    id: 'hf_alpha',
    name: 'Alpha',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'hi-in',
    languageName: 'Hindi',
  ),
  TtsVoice(
    id: 'hf_beta',
    name: 'Beta',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'hi-in',
    languageName: 'Hindi',
  ),
  TtsVoice(
    id: 'hm_omega',
    name: 'Omega',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'hi-in',
    languageName: 'Hindi',
  ),
  TtsVoice(
    id: 'hm_psi',
    name: 'Psi',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'hi-in',
    languageName: 'Hindi',
  ),
  // Italian
  TtsVoice(
    id: 'if_sara',
    name: 'Sara',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'it-it',
    languageName: 'Italian',
  ),
  TtsVoice(
    id: 'im_nicola',
    name: 'Nicola',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'it-it',
    languageName: 'Italian',
  ),
  // Japanese
  TtsVoice(
    id: 'jf_alpha',
    name: 'Alpha',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'ja-jp',
    languageName: 'Japanese',
  ),
  TtsVoice(
    id: 'jf_gongitsune',
    name: 'Gongitsune',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'ja-jp',
    languageName: 'Japanese',
  ),
  TtsVoice(
    id: 'jf_nezumi',
    name: 'Nezumi',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'ja-jp',
    languageName: 'Japanese',
  ),
  TtsVoice(
    id: 'jf_tebukuro',
    name: 'Tebukuro',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'ja-jp',
    languageName: 'Japanese',
  ),
  TtsVoice(
    id: 'jm_kumo',
    name: 'Kumo',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'ja-jp',
    languageName: 'Japanese',
  ),
  // Brazilian Portuguese
  TtsVoice(
    id: 'pf_dora',
    name: 'Dora',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'pt-br',
    languageName: 'Brazilian Portuguese',
  ),
  TtsVoice(
    id: 'pm_alex',
    name: 'Alex',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'pt-br',
    languageName: 'Brazilian Portuguese',
  ),
  TtsVoice(
    id: 'pm_santa',
    name: 'Santa',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'pt-br',
    languageName: 'Brazilian Portuguese',
  ),
  // Mandarin Chinese
  TtsVoice(
    id: 'zf_xiaobei',
    name: 'Xiaobei',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'zh-cn',
    languageName: 'Mandarin Chinese',
  ),
  TtsVoice(
    id: 'zf_xiaoni',
    name: 'Xiaoni',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'zh-cn',
    languageName: 'Mandarin Chinese',
  ),
  TtsVoice(
    id: 'zf_xiaoxiao',
    name: 'Xiaoxiao',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'zh-cn',
    languageName: 'Mandarin Chinese',
  ),
  TtsVoice(
    id: 'zf_xiaoyi',
    name: 'Xiaoyi',
    gender: 'female',
    grade: 'N/A',
    languageCode: 'zh-cn',
    languageName: 'Mandarin Chinese',
  ),
  TtsVoice(
    id: 'zm_yunjian',
    name: 'Yunjian',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'zh-cn',
    languageName: 'Mandarin Chinese',
  ),
  TtsVoice(
    id: 'zm_yunxi',
    name: 'Yunxi',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'zh-cn',
    languageName: 'Mandarin Chinese',
  ),
  TtsVoice(
    id: 'zm_yunxia',
    name: 'Yunxia',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'zh-cn',
    languageName: 'Mandarin Chinese',
  ),
  TtsVoice(
    id: 'zm_yunyang',
    name: 'Yunyang',
    gender: 'male',
    grade: 'N/A',
    languageCode: 'zh-cn',
    languageName: 'Mandarin Chinese',
  ),
];

/// Model download status
enum ModelDownloadStatus { notDownloaded, downloading, downloaded, error }

/// Service for managing Kokoro TTS using native Swift implementation
class TtsService {
  static const MethodChannel _channel = MethodChannel('com.mayari.tts');

  final AudioPlayer _audioPlayer = AudioPlayer();

  // Model download URLs
  static const String _modelUrl =
      'https://huggingface.co/mlx-community/Kokoro-82M-bf16/resolve/main/kokoro-v1_0.safetensors';
  static const String _voicesUrl =
      'https://raw.githubusercontent.com/mlalma/KokoroTestApp/main/Resources/voices.npz';

  // Download progress
  final StreamController<double> _downloadProgressController =
      StreamController<double>.broadcast();
  Stream<double> get downloadProgress => _downloadProgressController.stream;

  ModelDownloadStatus _downloadStatus = ModelDownloadStatus.notDownloaded;
  ModelDownloadStatus get downloadStatus => _downloadStatus;
  String? _lastAudiobookError;
  String? get lastAudiobookError => _lastAudiobookError;
  String? _activeAudiobookRequestId;
  bool _audiobookHandlerInstalled = false;

  /// Stream of player state changes
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  /// Current playback position
  Stream<Duration?> get positionStream => _audioPlayer.positionStream;

  /// Audio duration
  Duration? get duration => _audioPlayer.duration;

  /// Check if native TTS is available (macOS 15.0+)
  Future<bool> isNativeAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (e) {
      debugPrint('TTS: Native check failed: $e');
      return false;
    }
  }

  /// Get model status
  Future<Map<String, dynamic>> getModelStatus() async {
    try {
      final result = await _channel.invokeMethod<Map>('getModelStatus');
      return Map<String, dynamic>.from(result ?? {});
    } catch (e) {
      debugPrint('TTS: Model status check failed: $e');
      return {
        'loaded': false,
        'loading': false,
        'available': false,
        'error': e.toString(),
      };
    }
  }

  /// Check if server/native is healthy
  Future<bool> isServerHealthy({bool attemptAutoStart = true}) async {
    try {
      final nativeAvailable = await isNativeAvailable();
      if (!nativeAvailable) {
        debugPrint('TTS: Native TTS not available (requires macOS 15.0+)');
        return false;
      }

      final status = await getModelStatus();
      if (status['loaded'] == true) {
        return true;
      }

      // Check if model is downloaded
      final downloaded = await isModelDownloaded();
      if (!downloaded) {
        debugPrint('TTS: Model not downloaded yet');
        _downloadStatus = ModelDownloadStatus.notDownloaded;
        return false;
      }

      // Try to load the model only if attemptAutoStart is true
      if (attemptAutoStart) {
        try {
          final loaded = await _channel.invokeMethod<bool>('loadModel');
          return loaded ?? false;
        } catch (e) {
          final message = e.toString();
          debugPrint('TTS: Failed to load model: $message');
          // If model loading is already in progress from another request,
          // wait for readiness instead of reporting a hard failure.
          if (message.contains('LOADING') ||
              message.contains('already loading')) {
            return _waitForModelLoaded();
          }
          return false;
        }
      }

      return false;
    } catch (e) {
      debugPrint('TTS: Health check failed: $e');
      return false;
    }
  }

  Future<bool> _waitForModelLoaded({
    Duration timeout = const Duration(seconds: 12),
    Duration pollInterval = const Duration(milliseconds: 300),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final status = await getModelStatus();
      if (status['loaded'] == true) {
        return true;
      }
      await Future<void>.delayed(pollInterval);
    }
    return false;
  }

  /// Get the model directory path
  Future<Directory> _getModelDirectory() async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final appSupport = Directory(
      path.join(home, 'Library', 'Application Support', 'Mayari'),
    );
    final modelDir = Directory(path.join(appSupport.path, 'kokoro-model'));

    if (!modelDir.existsSync()) {
      modelDir.createSync(recursive: true);
    }

    return modelDir;
  }

  /// Public model directory path for diagnostics/UI display.
  Future<String> getModelDirectoryPath() async {
    final modelDir = await _getModelDirectory();
    return modelDir.path;
  }

  /// Check if model is downloaded
  Future<bool> isModelDownloaded() async {
    final modelDir = await _getModelDirectory();
    final modelFile = File(path.join(modelDir.path, 'kokoro-v1_0.safetensors'));
    final voicesFile = File(path.join(modelDir.path, 'voices.npz'));
    return modelFile.existsSync() && voicesFile.existsSync();
  }

  /// Download the TTS model
  Future<bool> downloadModel({
    void Function(double progress)? onProgress,
  }) async {
    if (_downloadStatus == ModelDownloadStatus.downloading) {
      return false;
    }

    _downloadStatus = ModelDownloadStatus.downloading;
    _downloadProgressController.add(0.0);

    try {
      final modelDir = await _getModelDirectory();

      // Download model file (~350MB)
      debugPrint('TTS: Downloading model...');
      final modelSuccess = await _downloadFile(
        _modelUrl,
        path.join(modelDir.path, 'kokoro-v1_0.safetensors'),
        onProgress: (progress) {
          final totalProgress = progress * 0.9; // Model is 90% of download
          _downloadProgressController.add(totalProgress);
          onProgress?.call(totalProgress);
        },
      );

      if (!modelSuccess) {
        _downloadStatus = ModelDownloadStatus.error;
        return false;
      }

      // Download voices file (~5MB)
      debugPrint('TTS: Downloading voices...');
      final voicesSuccess = await _downloadFile(
        _voicesUrl,
        path.join(modelDir.path, 'voices.npz'),
        onProgress: (progress) {
          final totalProgress = 0.9 + (progress * 0.1); // Voices is 10%
          _downloadProgressController.add(totalProgress);
          onProgress?.call(totalProgress);
        },
      );

      if (!voicesSuccess) {
        _downloadStatus = ModelDownloadStatus.error;
        return false;
      }

      _downloadStatus = ModelDownloadStatus.downloaded;
      _downloadProgressController.add(1.0);
      debugPrint('TTS: Model download complete');
      return true;
    } catch (e) {
      debugPrint('TTS: Download failed: $e');
      _downloadStatus = ModelDownloadStatus.error;
      return false;
    }
  }

  /// Download a file with progress
  Future<bool> _downloadFile(
    String url,
    String savePath, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        debugPrint('TTS: Download failed with status ${response.statusCode}');
        return false;
      }

      final contentLength = response.contentLength ?? 0;
      var downloadedBytes = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        if (contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          onProgress?.call(progress);
        }
      }

      await sink.close();
      client.close();

      return true;
    } catch (e) {
      debugPrint('TTS: File download error: $e');
      return false;
    }
  }

  /// Get available voices
  Future<List<TtsVoice>> getVoices() async {
    try {
      final result = await _channel.invokeMethod<List>('getVoices');
      if (result != null) {
        return result
            .map((v) => TtsVoice.fromJson(Map<String, dynamic>.from(v)))
            .toList();
      }
    } catch (e) {
      debugPrint('TTS: Failed to fetch voices: $e');
    }

    return defaultVoices.toList();
  }

  /// Synthesize text to speech and play it
  Future<bool> speak(
    String text, {
    String voice = 'bf_emma',
    double speed = 1.0,
  }) async {
    debugPrint(
      'TTS: speak() called with ${text.length} chars, voice=$voice, speed=$speed',
    );

    // Check if native is available and model loaded
    if (!await isServerHealthy(attemptAutoStart: true)) {
      debugPrint('TTS Error: Native TTS not ready');
      return false;
    }

    try {
      // Keep text bounded
      final truncatedText = text.length > 20000
          ? text.substring(0, 20000)
          : text;

      debugPrint('TTS: Sending synthesis request...');

      final result = await _channel.invokeMethod<bool>('speak', {
        'text': truncatedText,
        'voice': voice,
        'speed': speed,
      });

      if (result == true) {
        debugPrint('TTS: Playing audio...');
        return true;
      } else {
        debugPrint('TTS Error: Synthesis returned false');
        return false;
      }
    } catch (e) {
      debugPrint('TTS Error: Failed to synthesize/play: $e');
      return false;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    try {
      await _channel.invokeMethod('pause');
    } catch (e) {
      debugPrint('TTS: Pause error: $e');
    }
  }

  /// Resume playback
  Future<void> resume() async {
    try {
      await _channel.invokeMethod('resume');
    } catch (e) {
      debugPrint('TTS: Resume error: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('TTS: Stop error: $e');
    }
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    // Speed is set during speak() call for native TTS
    await _audioPlayer.setSpeed(speed);
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Check if currently playing
  bool get isPlaying {
    // Check native player state
    return _audioPlayer.playing;
  }

  /// Check native playing state
  Future<bool> isNativePlaying() async {
    try {
      final result = await _channel.invokeMethod<bool>('isPlaying');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Extract text from PDF bytes using native macOS PDF APIs.
  /// This is a lightweight extraction that doesn't require Python.
  Future<String> extractPdfText(
    Uint8List bytes, {
    String filename = 'document.pdf',
    int startPage = 1,
  }) async {
    try {
      final result = await _channel.invokeMethod<String>('extractPdfText', {
        'bytes': bytes,
        'filename': filename,
        'startPage': startPage,
      });
      return result ?? '';
    } catch (e) {
      debugPrint('TTS: Native PDF extraction failed: $e');
      return '';
    }
  }

  /// Test TTS with 3 different voices, saves WAV files to /tmp/
  Future<List<String>> testVoices() async {
    try {
      final result = await _channel.invokeMethod<List>('testVoices');
      if (result != null) {
        debugPrint('TTS Test: Generated ${result.length} audio files');
        for (final path in result) {
          debugPrint('TTS Test: $path');
        }
        return result.cast<String>();
      }
    } catch (e) {
      debugPrint('TTS Test Error: $e');
    }
    return [];
  }

  // Audiobook generation progress stream
  final StreamController<AudiobookProgress> _audiobookProgressController =
      StreamController<AudiobookProgress>.broadcast();
  Stream<AudiobookProgress> get audiobookProgress =>
      _audiobookProgressController.stream;

  /// Generate an audiobook from text chunks
  /// Returns the output file path and metadata on success
  Future<AudiobookResult?> generateAudiobook({
    required List<String> chunks,
    required String outputPath,
    required String title,
    String voice = 'bf_emma',
    double speed = 1.0,
  }) async {
    _lastAudiobookError = null;
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    _activeAudiobookRequestId = requestId;
    if (!await isServerHealthy(attemptAutoStart: true)) {
      _lastAudiobookError = 'Native TTS not ready for audiobook generation';
      debugPrint('TTS Error: $_lastAudiobookError');
      _activeAudiobookRequestId = null;
      return null;
    }

    if (!_audiobookHandlerInstalled) {
      _channel.setMethodCallHandler((call) async {
        if (call.method != 'audiobookProgress') return;
        final args = call.arguments as Map<dynamic, dynamic>;
        final progressRequestId = args['requestId'] as String?;
        if (_activeAudiobookRequestId != null &&
            progressRequestId != null &&
            progressRequestId != _activeAudiobookRequestId) {
          return;
        }
        _audiobookProgressController.add(
          AudiobookProgress(
            currentChunk: args['current'] as int,
            totalChunks: args['total'] as int,
            status: args['status'] as String,
            requestId: progressRequestId,
          ),
        );
      });
      _audiobookHandlerInstalled = true;
    }

    try {
      debugPrint(
        'TTS: Starting audiobook generation with ${chunks.length} chunks',
      );

      final result = await _channel
          .invokeMethod<Map>('generateAudiobook', {
            'chunks': chunks,
            'outputPath': outputPath,
            'title': title,
            'voice': voice,
            'speed': speed,
            'requestId': requestId,
          })
          .timeout(
            const Duration(minutes: 8),
            onTimeout: () =>
                throw TimeoutException('Audiobook generation timed out'),
          );

      if (result != null) {
        return AudiobookResult(
          path: result['path'] as String,
          duration: result['duration'] as double,
          chunks: result['chunks'] as int,
          format: result['format'] as String,
        );
      }
      _lastAudiobookError = 'Native plugin returned empty response';
    } catch (e) {
      _lastAudiobookError = e.toString();
      debugPrint(
        'TTS Error: Audiobook generation failed: $_lastAudiobookError',
      );
    } finally {
      if (_activeAudiobookRequestId == requestId) {
        _activeAudiobookRequestId = null;
      }
    }

    return null;
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _downloadProgressController.close();
    await _audiobookProgressController.close();
    await _audioPlayer.dispose();
  }
}

/// Progress update during audiobook generation
class AudiobookProgress {
  final int currentChunk;
  final int totalChunks;
  final String status;
  final String? requestId;

  AudiobookProgress({
    required this.currentChunk,
    required this.totalChunks,
    required this.status,
    this.requestId,
  });

  double get progress => totalChunks > 0 ? currentChunk / totalChunks : 0;
}

/// Result of audiobook generation
class AudiobookResult {
  final String path;
  final double duration;
  final int chunks;
  final String format;

  AudiobookResult({
    required this.path,
    required this.duration,
    required this.chunks,
    required this.format,
  });

  String get durationFormatted {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
