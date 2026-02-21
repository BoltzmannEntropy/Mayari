import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/source.dart';
import '../providers/sources_provider.dart';
import '../providers/text_reader_provider.dart';
import '../services/document_format.dart';
import '../services/document_text_extractor.dart';
import '../widgets/logs/logs_panel.dart';
import '../widgets/pdf_viewer/pdf_viewer_pane.dart';
import '../widgets/text_reader/text_reader_pane.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _initialSourceSelected = false;

  @override
  void initState() {
    super.initState();
    _keyboardFocusNode.requestFocus();

    // Set callback to auto-select default source when loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sourcesProvider.notifier).setOnDefaultSourceLoaded((sourceId) {
        ref.read(activeSourceIdProvider.notifier).state = sourceId;
      });
    });
  }

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  bool _isPdfSource(Source? source) =>
      source == null || source.documentType == SupportedDocumentType.pdf;

  Future<void> _handleActiveSourceChanged(Source? source) async {
    if (source == null) return;
    if (_isPdfSource(source)) return;

    ref.read(activeContentSourceProvider.notifier).state = ContentSource.text;
    await ref
        .read(textReaderProvider.notifier)
        .loadDocument(
          path: source.filePath,
          extractor: ref.read(documentTextExtractorProvider),
        );
  }

  Widget _buildContentToggle(
    BuildContext context,
    ContentSource source,
    Source? activeSource,
  ) {
    final isPdfSource = _isPdfSource(activeSource);
    final selectedSource = !isPdfSource && source == ContentSource.pdf
        ? ContentSource.text
        : source;
    final segments = <ButtonSegment<ContentSource>>[
      ButtonSegment<ContentSource>(
        value: ContentSource.pdf,
        enabled: isPdfSource,
        label: Text(isPdfSource ? 'PDF' : 'Document'),
        icon: Icon(
          isPdfSource ? Icons.picture_as_pdf : Icons.description_outlined,
          size: 18,
        ),
      ),
      const ButtonSegment<ContentSource>(
        value: ContentSource.text,
        label: Text('Text'),
        icon: Icon(Icons.article, size: 18),
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          SegmentedButton<ContentSource>(
            segments: segments,
            selected: {selectedSource},
            onSelectionChanged: (Set<ContentSource> selection) {
              if (!isPdfSource && selection.first == ContentSource.pdf) {
                ref.read(activeContentSourceProvider.notifier).state =
                    ContentSource.text;
                return;
              }
              ref.read(activeContentSourceProvider.notifier).state =
                  selection.first;
            },
            showSelectedIcon: false,
            style: ButtonStyle(visualDensity: VisualDensity.compact),
          ),
        ],
      ),
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    // Keyboard shortcuts handled by individual panes
  }

  @override
  Widget build(BuildContext context) {
    final activeSource = ref.watch(activeSourceProvider);
    final sources = ref.watch(sourcesProvider);
    final activeSourceId = ref.watch(activeSourceIdProvider);
    final isPdfSource = _isPdfSource(activeSource);

    ref.listen<Source?>(activeSourceProvider, (previous, next) {
      _handleActiveSourceChanged(next);
    });

    if (activeSource != null && !isPdfSource) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleActiveSourceChanged(activeSource);
      });
    }

    // Auto-select first source if none selected and sources exist
    if (!_initialSourceSelected &&
        activeSourceId == null &&
        sources.isNotEmpty) {
      _initialSourceSelected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(activeSourceIdProvider.notifier).state = sources.first.id;
      });
    }

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            activeSource != null ? 'Mayari - ${activeSource.title}' : 'Mayari',
          ),
          centerTitle: false,
          actions: [
            if (activeSource != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    activeSource.citation,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          ],
        ),
        body: Column(
          children: [
            // Main content area (PDF or Text)
            Expanded(
              child: Builder(
                builder: (context) {
                  final contentSource = ref.watch(activeContentSourceProvider);
                  return Column(
                    children: [
                      // Content source toggle
                      _buildContentToggle(context, contentSource, activeSource),
                      // Content pane
                      Expanded(
                        child:
                            (contentSource == ContentSource.pdf && isPdfSource)
                            ? const PdfViewerPane()
                            : const TextReaderPane(),
                      ),
                    ],
                  );
                },
              ),
            ),
            // System logs panel at bottom
            const LogsPanel(),
          ],
        ),
      ),
    );
  }
}
