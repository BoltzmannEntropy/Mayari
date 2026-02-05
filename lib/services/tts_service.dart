import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

/// Voice metadata for Kokoro British voices
class TtsVoice {
  final String id;
  final String name;
  final String gender;
  final String grade;
  final bool isDefault;

  const TtsVoice({
    required this.id,
    required this.name,
    required this.gender,
    required this.grade,
    this.isDefault = false,
  });

  factory TtsVoice.fromJson(Map<String, dynamic> json) {
    return TtsVoice(
      id: json['code'] as String,
      name: json['name'] as String,
      gender: json['gender'] as String,
      grade: json['grade'] as String,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  String get displayName => '$name ($grade)';
}

/// Available British voices (fallback if server unavailable)
const List<TtsVoice> defaultVoices = [
  TtsVoice(id: 'bf_emma', name: 'Emma', gender: 'female', grade: 'B-', isDefault: true),
  TtsVoice(id: 'bf_isabella', name: 'Isabella', gender: 'female', grade: 'C'),
  TtsVoice(id: 'bf_alice', name: 'Alice', gender: 'female', grade: 'D'),
  TtsVoice(id: 'bf_lily', name: 'Lily', gender: 'female', grade: 'D'),
  TtsVoice(id: 'bm_george', name: 'George', gender: 'male', grade: 'C'),
  TtsVoice(id: 'bm_fable', name: 'Fable', gender: 'male', grade: 'C'),
  TtsVoice(id: 'bm_lewis', name: 'Lewis', gender: 'male', grade: 'D+'),
  TtsVoice(id: 'bm_daniel', name: 'Daniel', gender: 'male', grade: 'D'),
];

/// Service for managing Kokoro TTS server and audio playback
class TtsService {
  static const int _serverPort = 8787;
  static const String _serverHost = '127.0.0.1';

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Stream of player state changes
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  /// Current playback position
  Stream<Duration?> get positionStream => _audioPlayer.positionStream;

  /// Audio duration
  Duration? get duration => _audioPlayer.duration;

  /// Get the base URL for the TTS server
  String get _baseUrl => 'http://$_serverHost:$_serverPort';

  /// Check if the server is responding
  Future<bool> isServerHealthy() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Get available voices from the server
  Future<List<TtsVoice>> getVoices() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/kokoro/voices'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final voiceList = data['voices'] as List;
        return voiceList.map((v) => TtsVoice.fromJson(v)).toList();
      }
    } catch (e) {
      print('TTS: Failed to fetch voices: $e');
    }

    return defaultVoices.toList();
  }

  /// Synthesize text to speech and play it
  Future<bool> speak(String text, {String voice = 'bf_emma', double speed = 1.0}) async {
    print('TTS: speak() called with ${text.length} chars, voice=$voice, speed=$speed');

    // Check if server is running
    if (!await isServerHealthy()) {
      print('TTS Error: Server not running. Start it with: mayarictl tts start');
      return false;
    }

    try {
      // Truncate text if too long
      final truncatedText = text.length > 5000 ? text.substring(0, 5000) : text;
      print('TTS: Sending synthesis request...');

      // Request synthesis using new API
      final response = await http.post(
        Uri.parse('$_baseUrl/api/kokoro/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': truncatedText,
          'voice': voice,
          'speed': speed,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        print('TTS Error: Synthesis failed with status ${response.statusCode}');
        print('TTS Error: Response body: ${response.body}');
        return false;
      }

      final data = json.decode(response.body);
      final audioUrl = data['audio_url'] as String;
      final fullUrl = '$_baseUrl$audioUrl';

      print('TTS: Got audio URL: $fullUrl');

      // Play the audio from URL
      await _audioPlayer.setUrl(fullUrl);
      await _audioPlayer.play();
      print('TTS: Playing audio...');
      return true;
    } catch (e) {
      print('TTS Error: Failed to synthesize/play: $e');
      return false;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await _audioPlayer.play();
  }

  /// Stop playback
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setSpeed(speed);
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Check if currently playing
  bool get isPlaying => _audioPlayer.playing;

  /// Dispose resources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}
