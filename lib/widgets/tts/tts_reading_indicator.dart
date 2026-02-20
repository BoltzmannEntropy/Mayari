import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tts_provider.dart';

class TtsReadingIndicator extends ConsumerWidget {
  const TtsReadingIndicator({super.key});

  String _cleanWord(String token) {
    return token.toLowerCase().replaceAll(
      RegExp(r'^[^a-z0-9]+|[^a-z0-9]+$'),
      '',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsProvider);

    final colorScheme = Theme.of(context).colorScheme;
    final previewText = ttsState.currentPreviewText;
    final totalWords = ttsState.currentWords.length;
    final rawWord = ttsState.currentWordIndex + 1;
    final clampedWord = totalWords == 0 ? 0 : rawWord.clamp(1, totalWords);
    final progress = totalWords == 0 ? 0.0 : clampedWord / totalWords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        border: Border(bottom: BorderSide(color: colorScheme.primary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ttsState.isPaused
                    ? Icons.pause_circle
                    : (ttsState.isLoading
                          ? Icons.hourglass_empty
                          : Icons.volume_up),
                size: 20,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ttsState.isLoading
                      ? 'Preparing audio...'
                      : (ttsState.isPaused
                            ? 'Paused'
                            : (ttsState.isPlaying
                                  ? 'Sentence ${ttsState.currentParagraphIndex + 1}/${ttsState.totalParagraphs}'
                                  : 'Read Aloud Idle')),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          if (previewText.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPreviewText(context, ttsState, previewText),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'No sentence preview yet.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
          if (totalWords > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: colorScheme.surface,
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              'Word $clampedWord of $totalWords',
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewText(
    BuildContext context,
    TtsState ttsState,
    String sentence,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseStyle = TextStyle(
      fontSize: 14,
      height: 1.35,
      color: colorScheme.onPrimaryContainer,
    );
    final highlightedStyle = baseStyle.copyWith(
      fontWeight: FontWeight.w700,
      backgroundColor: colorScheme.primary.withValues(alpha: 0.25),
    );

    final spans = <InlineSpan>[];
    final tokenPattern = RegExp(r'\S+');
    var cursor = 0;
    var trackedIndex = -1;

    for (final match in tokenPattern.allMatches(sentence)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: sentence.substring(cursor, match.start)));
      }

      final token = match.group(0) ?? '';
      final shouldTrack = _cleanWord(token).length >= 2;
      if (shouldTrack) trackedIndex++;

      final isActiveWord =
          ttsState.isPlaying &&
          ttsState.currentWordIndex >= 0 &&
          shouldTrack &&
          trackedIndex == ttsState.currentWordIndex;

      spans.add(
        TextSpan(
          text: token,
          style: isActiveWord ? highlightedStyle : baseStyle,
        ),
      );
      cursor = match.end;
    }

    if (cursor < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(cursor)));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
