import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pdf_provider.dart';
import '../providers/sources_provider.dart';
import '../widgets/pdf_viewer/pdf_viewer_pane.dart';
import '../widgets/quotes_panel/quotes_panel.dart';

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  double _splitPosition = 0.6;

  @override
  void initState() {
    super.initState();
  }

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
              );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Quote added from page $page'),
              duration: const Duration(seconds: 2),
            ),
          );
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
        body: LayoutBuilder(
          builder: (context, constraints) {
            final leftWidth = constraints.maxWidth * _splitPosition;
            final rightWidth = constraints.maxWidth * (1 - _splitPosition);

            return Row(
              children: [
                SizedBox(
                  width: leftWidth - 4,
                  child: const PdfViewerPane(),
                ),
                MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        _splitPosition += details.delta.dx / constraints.maxWidth;
                        _splitPosition = _splitPosition.clamp(0.3, 0.8);
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
                SizedBox(
                  width: rightWidth - 4,
                  child: const QuotesPanel(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
