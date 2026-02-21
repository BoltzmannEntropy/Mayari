import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/audiobook_provider.dart';
import '../../providers/tts_provider.dart';
import '../../services/tts_service.dart';

class SpeakerCard extends StatelessWidget {
  const SpeakerCard({
    super.key,
    required this.voice,
    required this.isSelected,
    required this.onTap,
  });

  final TtsVoice voice;
  final bool isSelected;
  final VoidCallback onTap;

  Color get _genderColor =>
      voice.gender == 'female' ? Colors.pink : Colors.blue;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 118,
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
            Text(
              '${voice.languageName} • ${voice.grade}',
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

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.isAll,
  });

  final String label;
  final int count;
  final bool isSelected;
  final bool isAll;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.7)
              : Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAll ? Icons.language : Icons.translate,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$label ($count)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpeakerCardsPanel extends ConsumerWidget {
  const SpeakerCardsPanel({super.key});

  Future<void> _queueLanguageTests(
    BuildContext context,
    WidgetRef ref,
    List<TtsVoice> voices,
    Set<String> selectedLanguages,
  ) async {
    if (voices.isEmpty) return;
    final ttsState = ref.read(ttsProvider);
    final filteredVoices = selectedLanguages.isEmpty
        ? voices
        : voices
              .where((v) => selectedLanguages.contains(v.languageCode))
              .toList();
    if (filteredVoices.isEmpty) return;

    TtsVoice pickVoice(String preferredLanguage, int fallbackIndex) {
      final byLanguage = filteredVoices
          .where((voice) => voice.languageCode == preferredLanguage)
          .toList();
      if (byLanguage.isNotEmpty) return byLanguage.first;
      return filteredVoices[fallbackIndex % filteredVoices.length];
    }

    final jobs = ref.read(audiobookJobsProvider.notifier);
    final germanVoice = pickVoice('en-us', 0);
    final russianVoice = pickVoice('en-gb', 1);

    await jobs.enqueue(
      title: 'Language Test - German Sample',
      chunks: const [
        'Guten Tag! Dies ist ein kurzer deutscher Beispielsatz, um die Stimme im Testlauf zu pruefen.',
      ],
      voice: germanVoice.id,
      speed: ttsState.speed,
    );
    await jobs.enqueue(
      title: 'Language Test - Russian Sample',
      chunks: const [
        'Privet! Eto korotkaya russkaya testovaya fraza dlya proverki golosa v ocheredi zadach.',
      ],
      voice: russianVoice.id,
      speed: ttsState.speed,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Queued language test jobs: German and Russian samples.',
          ),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voicesAsync = ref.watch(ttsVoicesProvider);
    final ttsState = ref.watch(ttsProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);
    final selectedLanguageCodes = ref.watch(selectedVoiceLanguageCodesProvider);

    return voicesAsync.when(
      data: (voices) {
        final sortedVoices = [
          ...voices.where((v) => v.gender == 'female'),
          ...voices.where((v) => v.gender == 'male'),
        ];

        final languageCounts = <String, int>{};
        final languageLabels = <String, String>{};
        for (final voice in sortedVoices) {
          languageCounts[voice.languageCode] =
              (languageCounts[voice.languageCode] ?? 0) + 1;
          languageLabels[voice.languageCode] = voice.languageName;
        }

        final filteredVoices = selectedLanguageCodes.isEmpty
            ? sortedVoices
            : sortedVoices
                  .where((v) => selectedLanguageCodes.contains(v.languageCode))
                  .toList();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLowest,
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _LanguageCard(
                              label: 'All',
                              count: sortedVoices.length,
                              isSelected: selectedLanguageCodes.isEmpty,
                              isAll: true,
                              onTap: () =>
                                  ref
                                          .read(
                                            selectedVoiceLanguageCodesProvider
                                                .notifier,
                                          )
                                          .state =
                                      <String>{},
                            ),
                          ),
                          ...languageCounts.entries.map((entry) {
                            final code = entry.key;
                            final selected = selectedLanguageCodes.contains(
                              code,
                            );
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _LanguageCard(
                                label: languageLabels[code] ?? code,
                                count: entry.value,
                                isSelected: selected,
                                isAll: false,
                                onTap: () {
                                  final next = {...selectedLanguageCodes};
                                  if (selected) {
                                    next.remove(code);
                                  } else {
                                    next.add(code);
                                  }
                                  ref
                                          .read(
                                            selectedVoiceLanguageCodesProvider
                                                .notifier,
                                          )
                                          .state =
                                      next;
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.science_outlined, size: 16),
                    tooltip: 'Queue German/Russian test jobs',
                    onPressed: () => _queueLanguageTests(
                      context,
                      ref,
                      sortedVoices,
                      selectedLanguageCodes,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filteredVoices.map((voice) {
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
            ],
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
                  'Voices',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                if (!_isExpanded) ...[
                  Consumer(
                    builder: (context, ref, _) {
                      final ttsState = ref.watch(ttsProvider);
                      final voicesAsync = ref.watch(ttsVoicesProvider);
                      return voicesAsync.when(
                        data: (voices) {
                          if (voices.isEmpty) return const SizedBox.shrink();
                          final currentVoice = voices.firstWhere(
                            (v) => v.id == ttsState.currentVoice,
                            orElse: () => voices.first,
                          );
                          return Text(
                            '${currentVoice.name} • ${currentVoice.languageName}',
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
        if (_isExpanded) const SpeakerCardsPanel(),
      ],
    );
  }
}
