import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../providers/pdf_provider.dart';
import '../../providers/sources_provider.dart';

class PdfViewerPane extends ConsumerStatefulWidget {
  const PdfViewerPane({super.key});

  @override
  ConsumerState<PdfViewerPane> createState() => _PdfViewerPaneState();
}

class _PdfViewerPaneState extends ConsumerState<PdfViewerPane> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfController;
  String? _selectedText;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;
  bool _isSearching = false;
  bool _showSearchBar = false;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _searchController.dispose();
    _searchResult?.clear();
    super.dispose();
  }

  void _addQuote() {
    final source = ref.read(activeSourceProvider);
    final text = _selectedText;
    final page = ref.read(currentPageProvider);

    if (source == null || text == null || text.isEmpty) return;

    ref.read(sourcesProvider.notifier).addQuote(
          sourceId: source.id,
          text: text,
          pageNumber: page,
        );

    setState(() => _selectedText = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quote added from page $page'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _clearSearch();
      }
    });
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty || _pdfController == null) return;

    setState(() => _isSearching = true);

    _searchResult?.clear();
    _searchResult = _pdfController!.searchText(query);

    _searchResult?.addListener(() {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    });
  }

  void _nextResult() {
    _searchResult?.nextInstance();
    setState(() {});
  }

  void _previousResult() {
    _searchResult?.previousInstance();
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _searchResult?.clear();
    _searchResult = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeSource = ref.watch(activeSourceProvider);
    final highlightMode = ref.watch(highlightModeProvider);

    if (activeSource == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Open a PDF to get started',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    final file = File(activeSource.filePath);
    if (!file.existsSync()) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'File not found:\n${activeSource.filePath}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(highlightMode),
        if (_showSearchBar) _buildSearchBar(),
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: highlightMode
                    ? BoxDecoration(
                        border: Border.all(color: Colors.orange, width: 3),
                      )
                    : null,
                child: SfPdfViewer.file(
                  file,
                  key: _pdfViewerKey,
                  controller: _pdfController,
                  onDocumentLoaded: (details) {
                    ref.read(totalPagesProvider.notifier).state =
                        details.document.pages.count;
                  },
                  onPageChanged: (details) {
                    ref.read(currentPageProvider.notifier).state =
                        details.newPageNumber;
                  },
                  onTextSelectionChanged: (details) {
                    final text = details.selectedText;
                    setState(() => _selectedText = text);
                    ref.read(selectedTextProvider.notifier).state = text;

                    if (highlightMode &&
                        text != null &&
                        text.trim().isNotEmpty) {
                      _addQuote();
                    }
                  },
                ),
              ),
              if (_selectedText != null &&
                  _selectedText!.isNotEmpty &&
                  !highlightMode)
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: FloatingActionButton.extended(
                    onPressed: _addQuote,
                    icon: const Icon(Icons.add),
                    label: const Text('Add to Quotes'),
                  ),
                ),
            ],
          ),
        ),
        _buildPageIndicator(),
      ],
    );
  }

  Widget _buildToolbar(bool highlightMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _pdfController?.zoomLevel -= 0.25,
            tooltip: 'Zoom out',
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _pdfController?.zoomLevel += 0.25,
            tooltip: 'Zoom in',
          ),
          const VerticalDivider(),
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: () => _pdfController?.jumpToPage(1),
            tooltip: 'First page',
          ),
          IconButton(
            icon: const Icon(Icons.navigate_before),
            onPressed: () => _pdfController?.previousPage(),
            tooltip: 'Previous page',
          ),
          IconButton(
            icon: const Icon(Icons.navigate_next),
            onPressed: () => _pdfController?.nextPage(),
            tooltip: 'Next page',
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: () {
              final total = ref.read(totalPagesProvider);
              _pdfController?.jumpToPage(total);
            },
            tooltip: 'Last page',
          ),
          const VerticalDivider(),
          IconButton(
            icon: Icon(
              _showSearchBar ? Icons.search_off : Icons.search,
              color: _showSearchBar
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            onPressed: _toggleSearch,
            tooltip: 'Search (Cmd/Ctrl+F)',
          ),
          const Spacer(),
          Tooltip(
            message: 'Highlight mode: auto-capture selections (Cmd/Ctrl+H)',
            child: FilterChip(
              label: const Text('Highlight Mode'),
              selected: highlightMode,
              onSelected: (value) {
                ref.read(highlightModeProvider.notifier).state = value;
              },
              avatar: Icon(
                highlightMode ? Icons.highlight : Icons.highlight_outlined,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final hasResults = _searchResult != null && _searchResult!.totalInstanceCount > 0;
    final currentIndex = _searchResult?.currentInstanceIndex ?? 0;
    final totalCount = _searchResult?.totalInstanceCount ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search in PDF...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _clearSearch,
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                ),
                style: const TextStyle(fontSize: 14),
                onSubmitted: (_) => _performSearch(),
                autofocus: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (_isSearching)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: _performSearch,
              tooltip: 'Search',
              visualDensity: VisualDensity.compact,
            ),
          if (hasResults) ...[
            const SizedBox(width: 8),
            Text(
              '$currentIndex / $totalCount',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: _previousResult,
              tooltip: 'Previous result',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: _nextResult,
              tooltip: 'Next result',
              visualDensity: VisualDensity.compact,
            ),
          ],
          if (_searchResult != null && totalCount == 0 && !_isSearching)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                'No results',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    final currentPage = ref.watch(currentPageProvider);
    final totalPages = ref.watch(totalPagesProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Page $currentPage of $totalPages',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
