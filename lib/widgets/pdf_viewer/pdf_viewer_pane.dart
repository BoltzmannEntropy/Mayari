import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../providers/library_provider.dart';
import '../../providers/pdf_provider.dart';
import '../../providers/sources_provider.dart';
import '../../providers/tts_provider.dart';
import '../dialogs/source_metadata_dialog.dart';
import '../dialogs/settings_dialog.dart';
import '../tts/speaker_cards.dart';

class PdfViewerPane extends ConsumerStatefulWidget {
  const PdfViewerPane({super.key});

  @override
  ConsumerState<PdfViewerPane> createState() => _PdfViewerPaneState();
}

class _PdfViewerPaneState extends ConsumerState<PdfViewerPane> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfController;
  String? _selectedText;
  bool _isDragging = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;
  bool _isSearching = false;
  bool _showSearchBar = false;
  bool _isExtractingTextForTts = false;

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

  String _normalizeExtractedPdfText(String text) {
    var normalized = text.replaceAll('\u00A0', ' ').replaceAll('\r', '\n');
    normalized = normalized.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');
    normalized = normalized.replaceAll(
      RegExp(r'([.!?;:,])(?=[A-Za-z])'),
      r'$1 ',
    );
    normalized = normalized.replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[ \t]+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return normalized.trim();
  }

  bool _looksCorruptedPdfText(String text) {
    if (text.trim().isEmpty) return true;
    final collapsed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return true;
    final letters = RegExp(r'[A-Za-z]').allMatches(collapsed).length;
    final spaces = RegExp(r'\s').allMatches(collapsed).length;
    if (letters < 40) return false;
    return spaces < (letters * 0.06);
  }

  String _extractPdfTextLocally(Uint8List bytes, int startPage) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final pageCount = document.pages.count;
      final startIndex = startPage.clamp(0, pageCount - 1);
      final raw = extractor.extractText(
        startPageIndex: startIndex,
        endPageIndex: pageCount - 1,
      );
      return _normalizeExtractedPdfText(raw);
    } finally {
      document.dispose();
    }
  }

  /// Extract text from the current page onwards for TTS.
  Future<void> _extractTextForTts() async {
    final activeSource = ref.read(activeSourceProvider);
    if (activeSource == null) {
      debugPrint('TTS: No active source');
      return;
    }

    final file = File(activeSource.filePath);
    if (!file.existsSync()) {
      debugPrint('TTS: File does not exist: ${activeSource.filePath}');
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      final currentPage = ref.read(currentPageProvider);
      String text = '';

      if (mounted) {
        setState(() => _isExtractingTextForTts = true);
      }

      final service = ref.read(ttsServiceProvider);
      try {
        text = await service.extractPdfText(
          bytes,
          filename: p.basename(activeSource.filePath),
        );
      } catch (e) {
        debugPrint(
          'TTS: Backend extraction unavailable, using local extraction: $e',
        );
      }

      if (text.trim().isEmpty || _looksCorruptedPdfText(text)) {
        text = _extractPdfTextLocally(bytes, currentPage - 1);
      } else {
        text = _normalizeExtractedPdfText(text);
      }

      debugPrint('TTS: Extracted text length: ${text.length} chars');
      if (text.isNotEmpty) {
        ref.read(ttsProvider.notifier).setContent(text);
        debugPrint('TTS: Content set, ready to play');
      } else {
        debugPrint('TTS: No text extracted');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No text found on this page. Try selecting text manually.',
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('TTS: Exception during extraction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract text: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtractingTextForTts = false);
      }
    }
  }

  /// Handle TTS play request
  Future<void> _handleTtsPlay() async {
    debugPrint('TTS: _handleTtsPlay called');
    final ttsState = ref.read(ttsProvider);

    // If there's selected text, use that
    if (_selectedText != null && _selectedText!.isNotEmpty) {
      debugPrint('TTS: Using selected text (${_selectedText!.length} chars)');
      ref.read(ttsProvider.notifier).setContent(_selectedText!);
      ref.read(ttsProvider.notifier).play();
      return;
    }

    // If already has content and paused, resume
    if (ttsState.isPaused) {
      debugPrint('TTS: Resuming paused playback');
      ref.read(ttsProvider.notifier).resume();
      return;
    }

    // Otherwise, extract text from PDF
    debugPrint('TTS: Extracting text from PDF...');
    await _extractTextForTts();

    // Check if we got content
    final updatedState = ref.read(ttsProvider);
    debugPrint(
      'TTS: After extraction, paragraphs: ${updatedState.paragraphs.length}',
    );
    if (updatedState.paragraphs.isEmpty) {
      debugPrint('TTS: No paragraphs to play');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No text to read. Select some text or try a different page.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    debugPrint('TTS: Starting playback');
    ref.read(ttsProvider.notifier).play();
  }

  Future<void> _addQuote() async {
    if (!mounted) return;
    final source = ref.read(activeSourceProvider);
    final text = _selectedText;
    final page = ref.read(currentPageProvider);

    if (source == null || text == null || text.isEmpty) return;

    final added = await ref
        .read(sourcesProvider.notifier)
        .addQuote(sourceId: source.id, text: text, pageNumber: page);

    if (added && mounted) {
      setState(() => _selectedText = null);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added ? 'Quote added from page $page' : 'Quote already saved',
        ),
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

  Future<void> _openPdfFromPath(String filePath) async {
    final sources = ref.read(sourcesProvider);
    final existing = sources.where((s) => s.filePath == filePath).firstOrNull;
    if (existing != null) {
      ref.read(activeSourceIdProvider.notifier).state = existing.id;
      return;
    }

    final metadata = await showDialog<SourceMetadataResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => SourceMetadataDialog(
        initialTitle: p.basenameWithoutExtension(filePath),
      ),
    );

    if (metadata == null) return;

    final source = await ref
        .read(sourcesProvider.notifier)
        .addSource(
          title: metadata.title,
          author: metadata.author,
          year: metadata.year,
          publisher: metadata.publisher,
          filePath: filePath,
        );

    ref.read(activeSourceIdProvider.notifier).state = source.id;
  }

  Future<void> _handleDroppedFiles(List files) async {
    if (mounted) {
      setState(() => _isDragging = false);
    }
    if (files.isEmpty) return;

    final paths = files
        .map((file) => (file as dynamic).path)
        .whereType<String>()
        .toList();

    if (paths.isEmpty) return;

    final pdfPaths = paths
        .where(
          (path) =>
              FileSystemEntity.typeSync(path) == FileSystemEntityType.file &&
              p.extension(path).toLowerCase() == '.pdf',
        )
        .toList();

    if (pdfPaths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Drop a PDF file to open it')),
        );
      }
      return;
    }

    ref.read(libraryFolderProvider.notifier).state = p.dirname(pdfPaths.first);
    for (final path in pdfPaths) {
      await _openPdfFromPath(path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeSource = ref.watch(activeSourceProvider);
    final highlightMode = ref.watch(highlightModeProvider);

    // Build the main content area
    Widget mainContent;

    if (activeSource == null) {
      mainContent = const Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Open a PDF to get started\nor drop one here',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    } else {
      final file = File(activeSource.filePath);
      if (!file.existsSync()) {
        mainContent = Expanded(
          child: Center(
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
          ),
        );
      } else {
        mainContent = Expanded(
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
                    if (!mounted) return;
                    ref.read(totalPagesProvider.notifier).state =
                        details.document.pages.count;
                  },
                  onPageChanged: (details) {
                    if (!mounted) return;
                    ref.read(currentPageProvider.notifier).state =
                        details.newPageNumber;
                  },
                  onTextSelectionChanged: (details) {
                    if (!mounted) return;
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
        );
      }
    }

    // Always show toolbar at the top
    Widget content = Column(
      children: [
        _buildToolbar(highlightMode),
        const CollapsibleSpeakerCards(),
        if (_showSearchBar) _buildSearchBar(),
        mainContent,
        if (activeSource != null) _buildPageIndicator(),
      ],
    );

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          return _handleKeyEvent(event);
        }
        return KeyEventResult.ignored;
      },
      child: DropTarget(
        onDragEntered: (_) {
          if (mounted) setState(() => _isDragging = true);
        },
        onDragExited: (_) {
          if (mounted) setState(() => _isDragging = false);
        },
        onDragDone: (details) => _handleDroppedFiles(details.files),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: _isDragging
              ? BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.2),
                )
              : null,
          child: content,
        ),
      ),
    );
  }

  /// Handle keyboard events for TTS and navigation
  KeyEventResult _handleKeyEvent(KeyDownEvent event) {
    final ttsNotifier = ref.read(ttsProvider.notifier);
    final ttsState = ref.read(ttsProvider);

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

  Widget _buildToolbar(bool highlightMode) {
    final ttsState = ref.watch(ttsProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);
    final serverStatus = ref.watch(ttsServerStatusProvider);
    final backendStatus = ref.watch(backendStatusProvider);
    final backendStatusText =
        backendStatus.valueOrNull ?? 'Backend status unknown';

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
            _buildServerStatusIndicator(serverStatus, backendStatusText),
            const SizedBox(width: 2),
            // TTS Controls
            _buildTtsPlayButton(ttsState, ttsNotifier),
            IconButton(
              icon: const Icon(Icons.stop, size: 16),
              onPressed: ttsState.isStopped ? null : () => ttsNotifier.stop(),
              tooltip: 'Stop',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 16),
              onPressed: ttsState.currentParagraphIndex > 0
                  ? () => ttsNotifier.skipBackward()
                  : null,
              tooltip: 'Previous chunk',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 16),
              onPressed:
                  ttsState.currentParagraphIndex < ttsState.totalParagraphs - 1
                  ? () => ttsNotifier.skipForward()
                  : null,
              tooltip: 'Next chunk',
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
            _buildSpeedDropdown(ttsState, ttsNotifier),
            const SizedBox(width: 4),
            _buildVoiceDropdown(ttsState, ttsNotifier),
            const SizedBox(width: 4),
            // Zoom controls
            IconButton(
              icon: const Icon(Icons.zoom_out, size: 16),
              onPressed: () => _pdfController?.zoomLevel -= 0.25,
              tooltip: 'Zoom out',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 16),
              onPressed: () => _pdfController?.zoomLevel += 0.25,
              tooltip: 'Zoom in',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 4),
            // Page navigation
            IconButton(
              icon: const Icon(Icons.navigate_before, size: 16),
              onPressed: () => _pdfController?.previousPage(),
              tooltip: 'Previous',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.navigate_next, size: 16),
              onPressed: () => _pdfController?.nextPage(),
              tooltip: 'Next',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                _showSearchBar ? Icons.search_off : Icons.search,
                size: 16,
                color: _showSearchBar
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              onPressed: _toggleSearch,
              tooltip: 'Search',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.settings, size: 16),
              onPressed: () => showSettingsDialog(context),
              tooltip: 'Settings',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: 'Highlight mode',
              child: FilterChip(
                label: const Text('H', style: TextStyle(fontSize: 12)),
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
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildServerStatusIndicator(
    AsyncValue<bool> serverStatus,
    String backendStatusText,
  ) {
    return serverStatus.when(
      data: (isConnected) => Tooltip(
        message: isConnected
            ? 'TTS Server: Connected ($backendStatusText)'
            : 'TTS Server: Disconnected ($backendStatusText)',
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
        message: 'TTS Server: Error',
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

  Widget _buildTtsPlayButton(TtsState state, TtsNotifier notifier) {
    if (state.isLoading || _isExtractingTextForTts) {
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
          _handleTtsPlay();
        }
      },
      tooltip: _isExtractingTextForTts
          ? 'Extracting text'
          : (state.isPlaying ? 'Pause reading' : 'Read aloud'),
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

  Widget _buildSearchBar() {
    final hasResults =
        _searchResult != null && _searchResult!.totalInstanceCount > 0;
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
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
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
