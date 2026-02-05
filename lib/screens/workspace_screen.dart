import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pdf_provider.dart';
import '../providers/sources_provider.dart';
import '../widgets/library/library_sidebar.dart';
import '../widgets/logs/logs_panel.dart';
import '../widgets/pdf_viewer/pdf_viewer_pane.dart';
import '../widgets/quotes_panel/quotes_panel.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  static const double _libraryWidth = 200;
  double _splitPosition = 0.55; // Position between PDF viewer and quotes panel

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      final isCmd = HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed;

      if (isCmd && event.logicalKey == LogicalKeyboardKey.keyH) {
        final current = ref.read(highlightModeProvider);
        ref.read(highlightModeProvider.notifier).state = !current;
      }

      if (isCmd && event.logicalKey == LogicalKeyboardKey.keyD) {
        final source = ref.read(activeSourceProvider);
        final text = ref.read(selectedTextProvider);
        final page = ref.read(currentPageProvider);

        if (source != null && text != null && text.isNotEmpty) {
          ref.read(sourcesProvider.notifier).addQuote(
                sourceId: source.id,
                text: text,
                pageNumber: page,
              ).then((added) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  added ? 'Quote added from page $page' : 'Quote already saved',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSource = ref.watch(activeSourceProvider);

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: Text(activeSource != null
              ? 'Mayari - ${activeSource.title}'
              : 'Mayari'),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth - _libraryWidth;
                  final pdfWidth = availableWidth * _splitPosition;
                  final quotesWidth = availableWidth * (1 - _splitPosition);

                  return Row(
                    children: [
                      // Library sidebar (fixed width)
                      const SizedBox(
                        width: _libraryWidth,
                        child: LibrarySidebar(),
                      ),
                      // PDF Viewer
                      SizedBox(
                        width: pdfWidth - 4,
                        child: const PdfViewerPane(),
                      ),
                      // Resizable divider
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeColumn,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _splitPosition += details.delta.dx / availableWidth;
                              _splitPosition = _splitPosition.clamp(0.3, 0.75);
                            });
                          },
                          child: Container(
                            width: 8,
                            color: Theme.of(context).dividerColor,
                            child: Center(
                              child: Container(
                                width: 4,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Quotes panel
                      SizedBox(
                        width: quotesWidth - 4,
                        child: const QuotesPanel(),
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
