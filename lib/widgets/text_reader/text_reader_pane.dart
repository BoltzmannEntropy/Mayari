import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/text_reader_provider.dart';
import '../../providers/tts_provider.dart';
import '../tts/speaker_cards.dart';

class TextReaderPane extends ConsumerStatefulWidget {
  const TextReaderPane({super.key});

  @override
  ConsumerState<TextReaderPane> createState() => _TextReaderPaneState();
}

class _TextReaderPaneState extends ConsumerState<TextReaderPane> {
  final TextEditingController _editController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Initialize controller with current text
    final state = ref.read(textReaderProvider);
    _editController.text = state.markdownText;
  }

  @override
  void dispose() {
    _editController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isCmd =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final ttsState = ref.read(ttsProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);
    final textState = ref.read(textReaderProvider);

    // Cmd+E to toggle edit mode
    if (isCmd && event.logicalKey == LogicalKeyboardKey.keyE) {
      final notifier = ref.read(textReaderProvider.notifier);
      if (textState.isEditMode) {
        notifier.setText(_editController.text);
      }
      notifier.toggleEditMode();
      return KeyEventResult.handled;
    }

    // Don't handle TTS keys in edit mode
    if (textState.isEditMode) return KeyEventResult.ignored;

    // Space - Play/Pause TTS
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (ttsState.isPlaying) {
        ttsNotifier.pause();
      } else if (ttsState.isPaused) {
        ttsNotifier.resume();
      } else {
        _handleTtsPlay();
      }
      return KeyEventResult.handled;
    }

    // Escape - Stop TTS
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (!ttsState.isStopped) {
        ttsNotifier.stop();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _handleTtsPlay() {
    final textState = ref.read(textReaderProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);

    // Set the plain text content for TTS
    ttsNotifier.setContent(textState.plainText);
    ttsNotifier.play();
  }

  @override
  Widget build(BuildContext context) {
    final textState = ref.watch(textReaderProvider);
    final theme = Theme.of(context);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Container(
          color: theme.colorScheme.surface,
          child: Column(
            children: [
              // TTS Toolbar (like PDF viewer)
              _buildTtsToolbar(context),
              // Voice cards panel
              const CollapsibleSpeakerCards(),
              // Header toolbar with Edit/Reset
              _buildHeaderToolbar(context, textState),
              const Divider(height: 1),
              // Content area
              Expanded(
                child: textState.isEditMode
                    ? _buildEditMode(context, textState)
                    : _buildViewMode(context, textState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTtsToolbar(BuildContext context) {
    final ttsState = ref.watch(ttsProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);
    final serverStatus = ref.watch(ttsServerStatusProvider);
    final ttsStatus = ref.watch(ttsStatusProvider);
    final ttsStatusText =
        ttsStatus.valueOrNull ?? 'Checking TTS...';
    final textState = ref.watch(textReaderProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // TTS Server Status indicator
            _buildServerStatusIndicator(serverStatus, ttsStatusText),
            const SizedBox(width: 2),
            // TTS Controls
            _buildTtsPlayButton(ttsState, ttsNotifier, textState),
            IconButton(
              icon: const Icon(Icons.stop, size: 16),
              onPressed: ttsState.isStopped ? null : () => ttsNotifier.stop(),
              tooltip: 'Stop',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            // Skip backward
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 16),
              onPressed: ttsState.currentParagraphIndex > 0
                  ? () => ttsNotifier.skipBackward()
                  : null,
              tooltip: 'Previous paragraph',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            // Skip forward
            IconButton(
              icon: const Icon(Icons.skip_next, size: 16),
              onPressed:
                  ttsState.currentParagraphIndex < ttsState.totalParagraphs - 1
                  ? () => ttsNotifier.skipForward()
                  : null,
              tooltip: 'Next paragraph',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 8),
            // Speed dropdown
            _buildSpeedDropdown(ttsState, ttsNotifier),
            const SizedBox(width: 4),
            // Voice dropdown
            _buildVoiceDropdown(ttsState, ttsNotifier),
            const SizedBox(width: 8),
            // Paragraph indicator
            if (ttsState.totalParagraphs > 0)
              Text(
                '${ttsState.currentParagraphIndex + 1}/${ttsState.totalParagraphs}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerStatusIndicator(
    AsyncValue<bool> serverStatus,
    String ttsStatusText,
  ) {
    return serverStatus.when(
      data: (isConnected) => Tooltip(
        message: isConnected
            ? 'TTS: Ready ($ttsStatusText)'
            : 'TTS: Not Ready ($ttsStatusText)',
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isConnected ? Colors.green : Colors.red,
          ),
        ),
      ),
      loading: () => const SizedBox(
        width: 10,
        height: 10,
        child: CircularProgressIndicator(strokeWidth: 1),
      ),
      error: (_, _) => Tooltip(
        message: 'TTS: Error',
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.orange,
          ),
        ),
      ),
    );
  }

  Widget _buildTtsPlayButton(
    TtsState state,
    TtsNotifier notifier,
    TextReaderState textState,
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
      onPressed: textState.paragraphs.isEmpty
          ? null
          : () {
              if (state.isPlaying) {
                notifier.pause();
              } else if (state.isPaused) {
                notifier.resume();
              } else {
                _handleTtsPlay();
              }
            },
      tooltip: state.isPlaying ? 'Pause reading' : 'Read aloud',
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildSpeedDropdown(TtsState state, TtsNotifier notifier) {
    return PopupMenuButton<double>(
      initialValue: state.speed,
      onSelected: (speed) => notifier.setSpeed(speed),
      tooltip: 'Playback speed',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
            const Icon(Icons.arrow_drop_down, size: 16),
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

  Widget _buildVoiceDropdown(TtsState state, TtsNotifier notifier) {
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
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentVoice.name,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Icon(Icons.arrow_drop_down, size: 16),
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
                height: 28,
                child: Text(
                  'Female',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
                height: 28,
                child: Text(
                  'Male',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildHeaderToolbar(BuildContext context, TextReaderState textState) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Icon(
            Icons.article_outlined,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            'Text Reader',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Edit/View toggle button
          TextButton.icon(
            onPressed: () {
              final notifier = ref.read(textReaderProvider.notifier);
              if (textState.isEditMode) {
                // Save text before switching to view mode
                notifier.setText(_editController.text);
              }
              notifier.toggleEditMode();
            },
            icon: Icon(
              textState.isEditMode ? Icons.visibility : Icons.edit,
              size: 18,
            ),
            label: Text(textState.isEditMode ? 'View' : 'Edit'),
          ),
          const SizedBox(width: 8),
          // Clear/Reset button
          TextButton.icon(
            onPressed: () {
              ref.read(textReaderProvider.notifier).resetToDefault();
              _editController.text = defaultMarkdownText;
            },
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildEditMode(BuildContext context, TextReaderState textState) {
    final theme = Theme.of(context);

    // Update controller if text changed externally
    if (_editController.text != textState.markdownText) {
      _editController.text = textState.markdownText;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paste or type your text below (Markdown supported):',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: _editController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Paste your text here...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerLowest,
              ),
              onChanged: (text) {
                // Update provider on change
                ref.read(textReaderProvider.notifier).setText(text);
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Press Cmd+E to switch to view mode',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMode(BuildContext context, TextReaderState textState) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Markdown(
        data: textState.markdownText,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          h2: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          h3: theme.textTheme.titleLarge,
          p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          blockquote: theme.textTheme.bodyLarge?.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.6,
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: theme.colorScheme.primary, width: 4),
            ),
          ),
          blockquotePadding: const EdgeInsets.only(left: 16),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
          ),
          em: const TextStyle(fontStyle: FontStyle.italic),
          strong: const TextStyle(fontWeight: FontWeight.bold),
          code: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}
