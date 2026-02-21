import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/text_reader_provider.dart';
import '../../providers/tts_provider.dart';
import '../../providers/model_download_provider.dart';
import '../../providers/audiobook_provider.dart';
import '../dialogs/model_download_dialog.dart';
import '../tts/speaker_cards.dart';
import '../tts/tts_reading_indicator.dart';

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

  Future<void> _handleCreateAudiobook() async {
    final textState = ref.read(textReaderProvider);
    final ttsState = ref.read(ttsProvider);
    final chunks = textState.paragraphs
        .where((p) => p.trim().length > 8)
        .toList();
    if (chunks.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No text chunks found for audiobook generation'),
          ),
        );
      }
      return;
    }

    final title = textState.loadedDocumentTitle?.trim().isNotEmpty == true
        ? textState.loadedDocumentTitle!
        : 'Text Reader Audiobook';

    await ref
        .read(audiobookJobsProvider.notifier)
        .enqueue(
          title: title,
          chunks: chunks,
          voice: ttsState.currentVoice,
          speed: ttsState.speed,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Audiobook job queued (${chunks.length} chunks). Track it in Jobs.',
          ),
        ),
      );
    }
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
              const TtsReadingIndicator(),
              // Header toolbar with Edit/Reset
              _buildHeaderToolbar(context, textState),
              const Divider(height: 1),
              // Content area
              Expanded(
                child: textState.isLoadingDocument
                    ? const Center(child: CircularProgressIndicator())
                    : (textState.documentError != null
                          ? _buildErrorState(context, textState.documentError!)
                          : (textState.isEditMode
                                ? _buildEditMode(context, textState)
                                : _buildViewMode(context, textState))),
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
    final modelStatus = ref.watch(modelDownloadProvider);
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
            // Model status indicator
            _buildModelStatusIndicator(modelStatus),
            const SizedBox(width: 2),
            // TTS Controls (disabled if model not ready)
            _buildTtsPlayButton(ttsState, ttsNotifier, textState, modelStatus),
            IconButton(
              icon: const Icon(Icons.stop, size: 16),
              onPressed: (!modelStatus.isReady || ttsState.isStopped)
                  ? null
                  : () => ttsNotifier.stop(),
              tooltip: 'Stop',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            // Skip backward
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 16),
              onPressed:
                  (!modelStatus.isReady || ttsState.currentParagraphIndex <= 0)
                  ? null
                  : () => ttsNotifier.skipBackward(),
              tooltip: 'Previous paragraph',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            // Skip forward
            IconButton(
              icon: const Icon(Icons.skip_next, size: 16),
              onPressed:
                  (!modelStatus.isReady ||
                      ttsState.currentParagraphIndex >=
                          ttsState.totalParagraphs - 1)
                  ? null
                  : () => ttsNotifier.skipForward(),
              tooltip: 'Next paragraph',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            Container(
              margin: const EdgeInsets.only(left: 2, right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                ttsState.totalParagraphs == 0
                    ? '0/0'
                    : '${ttsState.currentParagraphIndex + 1}/${ttsState.totalParagraphs}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _buildSpeedSlider(ttsState, ttsNotifier),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: (!modelStatus.isReady || textState.paragraphs.isEmpty)
                  ? null
                  : _handleCreateAudiobook,
              icon: const Icon(Icons.audiotrack, size: 16),
              label: const Text('Create Audiobook'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelStatusIndicator(ModelDownloadStatus status) {
    if (status.isReady) {
      return Tooltip(
        message: 'TTS Ready',
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green,
          ),
        ),
      );
    }

    if (status.isDownloading) {
      return Tooltip(
        message: 'Downloading TTS model... ${(status.progress * 100).toInt()}%',
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            value: status.progress > 0 ? status.progress : null,
            strokeWidth: 2,
          ),
        ),
      );
    }

    // Not downloaded - show download button
    return TextButton.icon(
      onPressed: () => showModelDownloadDialog(context),
      icon: const Icon(Icons.cloud_download_outlined, size: 16),
      label: const Text('Download TTS'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildTtsPlayButton(
    TtsState state,
    TtsNotifier notifier,
    TextReaderState textState,
    ModelDownloadStatus modelStatus,
  ) {
    // If model not ready, show disabled button
    if (!modelStatus.isReady) {
      return IconButton(
        icon: Icon(
          Icons.play_arrow,
          size: 24,
          color: Theme.of(context).disabledColor,
        ),
        onPressed: null,
        tooltip: 'Download TTS model first',
        visualDensity: VisualDensity.compact,
      );
    }

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

  Widget _buildSpeedSlider(TtsState state, TtsNotifier notifier) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          child: Slider(
            value: state.speed,
            min: 0.5,
            max: 2.0,
            divisions: 150,
            label: '${state.speed.toStringAsFixed(2)}x',
            onChanged: (v) =>
                notifier.setSpeed(double.parse(v.toStringAsFixed(2))),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${state.speed.toStringAsFixed(2)}x',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
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
            textState.loadedDocumentTitle ?? 'Text Reader',
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

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 36),
            const SizedBox(height: 8),
            Text(
              'Failed to load document',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
