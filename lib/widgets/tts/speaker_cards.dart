import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/tts_provider.dart';
import '../../services/tts_service.dart';

/// Speaker card widget for voice selection - compact version
class SpeakerCard extends StatelessWidget {
  final TtsVoice voice;
  final bool isSelected;
  final VoidCallback onTap;

  const SpeakerCard({
    super.key,
    required this.voice,
    required this.isSelected,
    required this.onTap,
  });

  Color get _genderColor {
    return voice.gender == 'female' ? Colors.pink : Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.5)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Name with gender indicator
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _genderColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    voice.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            // Grade/quality
            Text(
              voice.grade,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[500],
                fontSize: 9,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Panel showing all speaker cards in a single scrollable row
class SpeakerCardsPanel extends ConsumerWidget {
  const SpeakerCardsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(ttsVoicesProvider);
    final ttsState = ref.watch(ttsProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);

    return voicesAsync.when(
      data: (voices) {
        // Sort: females first, then males
        final sortedVoices = [
          ...voices.where((v) => v.gender == 'female'),
          ...voices.where((v) => v.gender == 'male'),
        ];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sortedVoices.map((voice) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: SpeakerCard(
                    voice: voice,
                    isSelected: voice.id == ttsState.currentVoice,
                    onTap: () => ttsNotifier.setVoice(voice.id),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: const SizedBox(
          height: 44,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      ),
      error: (_, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: const Text(
          'Error loading voices',
          style: TextStyle(fontSize: 11),
        ),
      ),
    );
  }
}

/// Collapsible speaker cards panel - compact header
class CollapsibleSpeakerCards extends ConsumerStatefulWidget {
  const CollapsibleSpeakerCards({super.key});

  @override
  ConsumerState<CollapsibleSpeakerCards> createState() =>
      _CollapsibleSpeakerCardsState();
}

class _CollapsibleSpeakerCardsState
    extends ConsumerState<CollapsibleSpeakerCards> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle header - compact
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.record_voice_over,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Voice',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                // Show current voice when collapsed
                if (!_isExpanded) ...[
                  Consumer(
                    builder: (context, ref, _) {
                      final ttsState = ref.watch(ttsProvider);
                      final voicesAsync = ref.watch(ttsVoicesProvider);
                      return voicesAsync.when(
                        data: (voices) {
                          final currentVoice = voices.firstWhere(
                            (v) => v.id == ttsState.currentVoice,
                            orElse: () => voices.first,
                          );
                          return Text(
                            currentVoice.name,
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
                ],
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
        // Cards panel
        if (_isExpanded) const SpeakerCardsPanel(),
      ],
    );
  }
}
