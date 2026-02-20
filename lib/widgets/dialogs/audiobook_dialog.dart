import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../providers/tts_provider.dart';
import '../../providers/audiobook_provider.dart';
import '../../services/tts_service.dart';

/// Dialog for creating an audiobook from PDF text
class AudiobookDialog extends ConsumerStatefulWidget {
  final String title;
  final List<String> textChunks;

  const AudiobookDialog({
    super.key,
    required this.title,
    required this.textChunks,
  });

  @override
  ConsumerState<AudiobookDialog> createState() => _AudiobookDialogState();
}

class _AudiobookDialogState extends ConsumerState<AudiobookDialog> {
  bool _isGenerating = false;
  double _progress = 0;
  String _status = '';
  AudiobookResult? _result;
  StreamSubscription<AudiobookProgress>? _progressSubscription;

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    final service = ref.read(ttsServiceProvider);
    final ttsState = ref.read(ttsProvider);

    setState(() {
      _isGenerating = true;
      _progress = 0;
      _status = 'Starting...';
    });

    // Listen to progress updates
    _progressSubscription = service.audiobookProgress.listen((progress) {
      if (mounted) {
        setState(() {
          _progress = progress.progress;
          _status = progress.status;
        });
      }
    });

    // Generate output path
    final docsDir = Platform.environment['HOME'] ?? '/tmp';
    final sanitizedTitle = widget.title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = p.join(docsDir, 'Documents', 'Mayari Audiobooks', '${sanitizedTitle}_$timestamp.wav');

    // Create directory if needed
    final dir = Directory(p.dirname(outputPath));
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final result = await service.generateAudiobook(
      chunks: widget.textChunks,
      outputPath: outputPath,
      title: widget.title,
      voice: ttsState.currentVoice,
      speed: ttsState.speed,
    );

    _progressSubscription?.cancel();

    if (mounted) {
      setState(() {
        _isGenerating = false;
        _result = result;
        if (result != null) {
          _status = 'Complete!';

          // Save to audiobooks provider
          final audiobook = Audiobook(
            id: const Uuid().v4(),
            title: widget.title,
            path: result.path,
            durationSeconds: result.duration,
            chunks: result.chunks,
            voice: ttsState.currentVoice,
            speed: ttsState.speed,
            createdAt: DateTime.now(),
          );
          ref.read(audiobooksProvider.notifier).addAudiobook(audiobook);
        } else {
          _status = 'Generation failed';
        }
      });
    }
  }

  void _openInFinder() {
    if (_result != null) {
      Process.run('open', ['-R', _result!.path]);
    }
  }

  void _playAudiobook() {
    if (_result != null) {
      Process.run('open', [_result!.path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ttsState = ref.watch(ttsProvider);
    final voicesAsync = ref.watch(ttsVoicesProvider);

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.audiotrack),
          const SizedBox(width: 8),
          const Text('Create Audiobook'),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              widget.title,
              style: theme.textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.textChunks.length} paragraphs',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Voice info
            voicesAsync.when(
              data: (voices) {
                final currentVoice = voices.firstWhere(
                  (v) => v.id == ttsState.currentVoice,
                  orElse: () => voices.first,
                );
                return Row(
                  children: [
                    Icon(
                      currentVoice.gender == 'female' ? Icons.face_3 : Icons.face,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text('Voice: ${currentVoice.displayName}'),
                    const Spacer(),
                    Text('Speed: ${ttsState.speed}x'),
                  ],
                );
              },
              loading: () => const Text('Loading voice...'),
              error: (_, __) => const Text('Voice error'),
            ),

            const SizedBox(height: 24),

            // Progress section
            if (_isGenerating || _result != null) ...[
              LinearProgressIndicator(
                value: _result != null ? 1.0 : (_progress > 0 ? _progress : null),
              ),
              const SizedBox(height: 8),
              Text(
                _status,
                style: theme.textTheme.bodySmall,
              ),
            ],

            // Result section
            if (_result != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Audiobook Created',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Duration: ${_result!.durationFormatted}'),
                    Text('Format: ${_result!.format.toUpperCase()}'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _playAudiobook,
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Play'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _openInFinder,
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: const Text('Show in Finder'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_result != null ? 'Done' : 'Cancel'),
        ),
        if (!_isGenerating && _result == null)
          FilledButton.icon(
            onPressed: _startGeneration,
            icon: const Icon(Icons.audiotrack),
            label: const Text('Generate'),
          ),
      ],
    );
  }
}

/// Show the audiobook creation dialog
Future<void> showAudiobookDialog(
  BuildContext context, {
  required String title,
  required List<String> textChunks,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AudiobookDialog(
      title: title,
      textChunks: textChunks,
    ),
  );
}
