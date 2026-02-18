import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tts_provider.dart';

class TtsToolbar extends ConsumerWidget {
  final VoidCallback? onSettingsPressed;

  const TtsToolbar({super.key, this.onSettingsPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        _buildPlayPauseButton(context, ttsState, ttsNotifier),

        // Stop button
        IconButton(
          icon: const Icon(Icons.stop, size: 20),
          onPressed: ttsState.isStopped ? null : () => ttsNotifier.stop(),
          tooltip: 'Stop',
          visualDensity: VisualDensity.compact,
        ),

        // Skip backward
        IconButton(
          icon: const Icon(Icons.skip_previous, size: 20),
          onPressed: ttsState.currentParagraphIndex > 0
              ? () => ttsNotifier.skipBackward()
              : null,
          tooltip: 'Previous paragraph',
          visualDensity: VisualDensity.compact,
        ),

        // Skip forward
        IconButton(
          icon: const Icon(Icons.skip_next, size: 20),
          onPressed:
              ttsState.currentParagraphIndex < ttsState.totalParagraphs - 1
              ? () => ttsNotifier.skipForward()
              : null,
          tooltip: 'Next paragraph',
          visualDensity: VisualDensity.compact,
        ),

        const VerticalDivider(),

        // Speed dropdown
        _buildSpeedDropdown(context, ttsState, ttsNotifier),

        const SizedBox(width: 8),

        // Voice dropdown
        _buildVoiceDropdown(context, ref, ttsState, ttsNotifier),

        // Settings button (optional)
        if (onSettingsPressed != null) ...[
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.settings, size: 20),
            onPressed: onSettingsPressed,
            tooltip: 'TTS Settings',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }

  Widget _buildPlayPauseButton(
    BuildContext context,
    TtsState state,
    TtsNotifier notifier,
  ) {
    if (state.isLoading) {
      return Container(
        width: 40,
        height: 40,
        padding: const EdgeInsets.all(10),
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final isActive = state.isPlaying || state.isPaused;
    final icon = state.isPlaying ? Icons.pause : Icons.play_arrow;
    final color = isActive ? Theme.of(context).colorScheme.primary : null;

    return IconButton(
      icon: Icon(icon, size: 24, color: color),
      onPressed: () {
        if (state.isPlaying) {
          notifier.pause();
        } else if (state.isPaused) {
          notifier.resume();
        } else {
          notifier.play();
        }
      },
      tooltip: state.isPlaying ? 'Pause' : 'Play',
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSpeedDropdown(
    BuildContext context,
    TtsState state,
    TtsNotifier notifier,
  ) {
    return PopupMenuButton<double>(
      initialValue: state.speed,
      onSelected: (speed) => notifier.setSpeed(speed),
      tooltip: 'Playback speed',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              speedDisplayName(state.speed),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
      itemBuilder: (context) => speedOptions.map((speed) {
        return PopupMenuItem<double>(
          value: speed,
          child: Text(speedDisplayName(speed)),
        );
      }).toList(),
    );
  }

  Widget _buildVoiceDropdown(
    BuildContext context,
    WidgetRef ref,
    TtsState state,
    TtsNotifier notifier,
  ) {
    final voicesAsync = ref.watch(ttsVoicesProvider);

    return voicesAsync.when(
      data: (voices) {
        final currentVoice = voices.firstWhere(
          (v) => v.id == state.currentVoice,
          orElse: () => voices.first,
        );

        return PopupMenuButton<String>(
          initialValue: state.currentVoice,
          onSelected: (voiceId) => notifier.setVoice(voiceId),
          tooltip: 'Select voice',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentVoice.displayName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Icon(Icons.arrow_drop_down, size: 18),
              ],
            ),
          ),
          itemBuilder: (context) {
            final femaleVoices = voices
                .where((v) => v.gender == 'female')
                .toList();
            final maleVoices = voices.where((v) => v.gender == 'male').toList();

            return [
              const PopupMenuItem<String>(
                enabled: false,
                height: 30,
                child: Text(
                  'Female',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              ...femaleVoices.map(
                (voice) => PopupMenuItem<String>(
                  value: voice.id,
                  child: Text('${voice.name} (${voice.grade})'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                enabled: false,
                height: 30,
                child: Text(
                  'Male',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              ...maleVoices.map(
                (voice) => PopupMenuItem<String>(
                  value: voice.id,
                  child: Text('${voice.name} (${voice.grade})'),
                ),
              ),
            ];
          },
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: const Text('Error loading voices'),
      ),
    );
  }
}

/// Compact version of the TTS toolbar for smaller spaces
class TtsToolbarCompact extends ConsumerWidget {
  const TtsToolbarCompact({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(ttsProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Play/Pause button
        if (ttsState.isLoading)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            icon: Icon(
              ttsState.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 20,
              color: ttsState.isPlaying
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: () {
              if (ttsState.isPlaying) {
                ttsNotifier.pause();
              } else if (ttsState.isPaused) {
                ttsNotifier.resume();
              } else {
                ttsNotifier.play();
              }
            },
            tooltip: ttsState.isPlaying ? 'Pause' : 'Play',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),

        // Stop button
        IconButton(
          icon: const Icon(Icons.stop, size: 20),
          onPressed: ttsState.isStopped ? null : () => ttsNotifier.stop(),
          tooltip: 'Stop',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}
