import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../providers/library_provider.dart';
import '../providers/pdf_provider.dart';
import '../providers/sources_provider.dart';
import '../providers/text_reader_provider.dart';
import '../widgets/library/library_sidebar.dart';
import '../widgets/logs/logs_panel.dart';
import '../widgets/pdf_viewer/pdf_viewer_pane.dart';
import '../widgets/text_reader/text_reader_pane.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  static const double _libraryWidth = 200;
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

  Widget _buildContentToggle(BuildContext context, ContentSource source) {
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
            segments: const [
              ButtonSegment<ContentSource>(
                value: ContentSource.pdf,
                label: Text('PDF'),
                icon: Icon(Icons.picture_as_pdf, size: 18),
              ),
              ButtonSegment<ContentSource>(
                value: ContentSource.text,
                label: Text('Text'),
                icon: Icon(Icons.article, size: 18),
              ),
            ],
            selected: {source},
            onSelectionChanged: (Set<ContentSource> selection) {
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

    // Auto-select first source if none selected and sources exist
    if (!_initialSourceSelected && activeSourceId == null && sources.isNotEmpty) {
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
            // Main content area
            Expanded(
              child: Row(
                children: [
                  // Library sidebar (fixed width)
                  const SizedBox(
                    width: _libraryWidth,
                    child: LibrarySidebar(),
                  ),
                  // Main content area (PDF or Text)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final contentSource = ref.watch(activeContentSourceProvider);
                        return Column(
                          children: [
                            // Content source toggle
                            _buildContentToggle(context, contentSource),
                            // Content pane
                            Expanded(
                              child: contentSource == ContentSource.pdf
                                  ? const PdfViewerPane()
                                  : const TextReaderPane(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
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
