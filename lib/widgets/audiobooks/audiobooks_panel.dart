import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/audiobook_provider.dart';

/// Panel showing list of generated audiobooks with playback controls
class AudiobooksPanel extends ConsumerWidget {
  const AudiobooksPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audiobooks = ref.watch(audiobooksProvider);
    final playbackState = ref.watch(audiobookPlaybackProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Audiobooks',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '${audiobooks.length}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: audiobooks.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.audiotrack_outlined,
                            size: 32,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No audiobooks yet',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create one from a PDF',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: audiobooks.length,
                    itemBuilder: (context, index) {
                      final book = audiobooks[index];
                      return _AudiobookCard(
                        book: book,
                        isPlaying: playbackState.playingId == book.id && playbackState.isPlaying,
                        isPaused: playbackState.playingId == book.id && playbackState.isPaused,
                        position: playbackState.playingId == book.id ? playbackState.position : Duration.zero,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AudiobookCard extends ConsumerWidget {
  final Audiobook book;
  final bool isPlaying;
  final bool isPaused;
  final Duration position;

  const _AudiobookCard({
    required this.book,
    required this.isPlaying,
    required this.isPaused,
    required this.position,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isActive = isPlaying || isPaused;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? theme.colorScheme.primary : theme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title and delete
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 4, 0),
            child: Row(
              children: [
                Icon(
                  Icons.audiotrack,
                  size: 14,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    book.title,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 14),
                  onPressed: () => _confirmDelete(context, ref),
                  tooltip: 'Delete',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),

          // Info row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              '${book.durationFormatted} • ${book.sizeMb.toStringAsFixed(1)} MB • ${book.voice}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Progress bar (if playing/paused)
          if (isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: LinearProgressIndicator(
                value: book.durationSeconds > 0
                    ? position.inSeconds / book.durationSeconds
                    : 0,
                minHeight: 2,
              ),
            ),

          // Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
            child: Row(
              children: [
                // Play/Pause
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    size: 18,
                  ),
                  onPressed: () => _togglePlayPause(ref),
                  tooltip: isPlaying ? 'Pause' : 'Play',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),

                // Stop (only if active)
                if (isActive)
                  IconButton(
                    icon: const Icon(Icons.stop, size: 18),
                    onPressed: () => ref.read(audiobookPlaybackProvider.notifier).stop(),
                    tooltip: 'Stop',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),

                const Spacer(),

                // Show in Finder
                IconButton(
                  icon: const Icon(Icons.folder_open, size: 16),
                  onPressed: () => Process.run('open', ['-R', book.path]),
                  tooltip: 'Show in Finder',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _togglePlayPause(WidgetRef ref) {
    final notifier = ref.read(audiobookPlaybackProvider.notifier);
    if (isPlaying) {
      notifier.pause();
    } else if (isPaused) {
      notifier.resume();
    } else {
      notifier.play(book);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Audiobook'),
        content: Text('Delete "${book.title}"?\n\nThis will also delete the audio file.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(audiobooksProvider.notifier).deleteAudiobook(book.id);
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
