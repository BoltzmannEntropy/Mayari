import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:mayari/services/audiobook_chunking.dart';
import 'package:mayari/services/tts_service.dart';
import 'package:path/path.dart' as p;

const String _textAsset = String.fromEnvironment(
  'MAYARI_LONG_TEXT_ASSET',
  defaultValue: 'assets/examples/texts/public_domain_history_wells_excerpt.txt',
);
const String _voiceListDefine = String.fromEnvironment(
  'MAYARI_LONG_TEST_VOICES',
  defaultValue: 'bf_emma,bm_george',
);
const String _outputDirDefine = String.fromEnvironment(
  'MAYARI_LONG_TEST_OUTPUT_DIR',
  defaultValue: '',
);
const String _speedDefine = String.fromEnvironment(
  'MAYARI_LONG_TEST_SPEED',
  defaultValue: '1.0',
);
const String _maxCharsDefine = String.fromEnvironment(
  'MAYARI_LONG_TEST_MAX_CHARS',
  defaultValue: '90000',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final exitCode = await _run();
  exit(exitCode);
}

Future<int> _run() async {
  final service = TtsService();
  StreamSubscription<AudiobookProgress>? progressSub;
  var lastProgressLine = '';

  try {
    stdout.writeln('== Mayari Long Audiobook Runner ==');
    final speed = double.tryParse(_speedDefine) ?? 1.0;
    final maxChars = int.tryParse(_maxCharsDefine) ?? 90000;
    final voices = _voiceListDefine
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();

    if (voices.isEmpty) {
      stderr.writeln('No voices configured.');
      return 2;
    }

    stdout.writeln('Text asset: $_textAsset');
    stdout.writeln('Voices: ${voices.join(', ')}');
    stdout.writeln('Speed: $speed');
    stdout.writeln('Max chars: $maxChars');

    final downloaded = await service.isModelDownloaded();
    if (!downloaded) {
      stdout.writeln('Downloading Kokoro model...');
      var lastLoggedPercent = -1;
      final ok = await service.downloadModel(
        onProgress: (progress) {
          final percent = (progress * 100).floor();
          if (percent >= lastLoggedPercent + 5) {
            lastLoggedPercent = percent;
            stdout.writeln('Model download: $percent%');
          }
        },
      );
      if (!ok) {
        stderr.writeln('Failed to download model.');
        return 3;
      }
    }

    final ready = await service.isServerHealthy(attemptAutoStart: true);
    if (!ready) {
      stderr.writeln('Native Kokoro TTS is not ready.');
      return 4;
    }

    var text = await rootBundle.loadString(_textAsset);
    text = text.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    if (maxChars > 0 && text.length > maxChars) {
      text = text.substring(0, maxChars);
    }

    final chunks = AudiobookChunking.prepareTextForGeneration(text);
    if (chunks.isEmpty) {
      stderr.writeln('No chunks prepared from source text.');
      return 5;
    }
    stdout.writeln(
      'Prepared ${chunks.length} chunks from ${text.length} chars.',
    );

    final available = (await service.getVoices()).map((v) => v.id).toSet();
    final missingVoices = voices.where((v) => !available.contains(v)).toList();
    if (missingVoices.isNotEmpty) {
      stderr.writeln('Missing voices in catalog: ${missingVoices.join(', ')}');
      return 6;
    }

    final outputDir = _outputDirDefine.trim().isNotEmpty
        ? Directory(_outputDirDefine.trim())
        : Directory(
            p.join(
              Platform.environment['HOME'] ?? '/tmp',
              'Documents',
              'Mayari Audiobooks',
              'long-history-tests',
            ),
          );
    if (!outputDir.existsSync()) {
      outputDir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().toUtc().toIso8601String().replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    progressSub = service.audiobookProgress.listen((progress) {
      final line =
          'Progress: ${progress.currentChunk}/${progress.totalChunks} ${progress.status}';
      if (line == lastProgressLine) return;
      lastProgressLine = line;
      stdout.writeln(line);
    });

    final outputs = <Map<String, dynamic>>[];
    var failures = 0;

    for (final voice in voices) {
      final outputPath = p.join(
        outputDir.path,
        'long_history_${voice}_$timestamp.wav',
      );
      stdout.writeln('Generating voice $voice -> $outputPath');

      final result = await service.generateAudiobook(
        chunks: chunks,
        outputPath: outputPath,
        title: 'Long History Test ($voice)',
        voice: voice,
        speed: speed,
      );

      final file = File(outputPath);
      final exists = file.existsSync();
      final sizeBytes = exists ? file.lengthSync() : 0;
      final duration = result?.duration ?? 0.0;
      final ok = result != null && exists && sizeBytes > 1024 && duration > 1;
      if (!ok) {
        failures += 1;
      }

      outputs.add({
        'voice': voice,
        'path': outputPath,
        'ok': ok,
        'size_bytes': sizeBytes,
        'duration_seconds': duration,
        'chunks': result?.chunks ?? chunks.length,
        'error': ok ? null : service.lastAudiobookError,
      });

      stdout.writeln(
        ok
            ? 'Done: $voice (${(sizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB, ${duration.toStringAsFixed(1)}s)'
            : 'Failed: $voice (${service.lastAudiobookError ?? 'unknown error'})',
      );
    }

    final manifestPath = p.join(
      outputDir.path,
      'long_history_manifest_$timestamp.json',
    );
    final manifest = {
      'generated_at': DateTime.now().toIso8601String(),
      'text_asset': _textAsset,
      'max_chars': maxChars,
      'voices': voices,
      'chunk_count': chunks.length,
      'speed': speed,
      'outputs': outputs,
    };
    await File(manifestPath).writeAsString(
      const JsonEncoder.withIndent('  ').convert(manifest),
      flush: true,
    );

    stdout.writeln('Manifest: $manifestPath');
    stdout.writeln(
      failures == 0
          ? 'All audiobook generations completed successfully.'
          : '$failures generation(s) failed.',
    );
    return failures == 0 ? 0 : 7;
  } finally {
    await progressSub?.cancel();
    await service.dispose();
  }
}
