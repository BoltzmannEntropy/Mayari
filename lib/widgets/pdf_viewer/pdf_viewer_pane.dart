import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import '../../providers/library_provider.dart';
import '../../providers/pdf_provider.dart';
import '../../providers/sources_provider.dart';
import '../../providers/tts_provider.dart';
import '../../providers/model_download_provider.dart';
import '../../providers/audiobook_provider.dart';
import '../dialogs/model_download_dialog.dart';
import '../tts/speaker_cards.dart';
import '../tts/tts_reading_indicator.dart';

class _SearchQueryCandidate {
  const _SearchQueryCandidate({
    required this.query,
    required this.expectedOccurrence,
    required this.totalExpectedOccurrences,
    required this.tokenCount,
  });

  final String query;
  final int expectedOccurrence;
  final int totalExpectedOccurrences;
  final int tokenCount;
}

enum _SearchWaitOutcome { matched, noMatch, unavailable, superseded }

class _PdfWordAnchor {
  const _PdfWordAnchor({required this.normalizedWord, required this.line});

  final String normalizedWord;
  final PdfTextLine line;
}

class PdfViewerPane extends ConsumerStatefulWidget {
  const PdfViewerPane({super.key});

  @override
  ConsumerState<PdfViewerPane> createState() => _PdfViewerPaneState();
}

class _PdfViewerPaneState extends ConsumerState<PdfViewerPane> {
  static const Color _activeReadAloudHighlightColor = Color.fromARGB(
    220,
    68,
    84,
    170,
  );
  static const Color _trailingReadAloudHighlightColor = Color.fromARGB(
    150,
    255,
    213,
    79,
  );

  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  PdfViewerController? _pdfController;
  String? _selectedText;
  bool _isDragging = false;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  PdfTextSearchResult? _searchResult;
  PdfTextSearchResult? _readAloudSearchResult;
  bool _isSearching = false;
  bool _showSearchBar = false;
  bool _isExtractingTextForTts = false;

  final List<Annotation> _activeReadAloudAnnotations = <Annotation>[];
  final List<_PdfWordAnchor> _pdfWordAnchors = <_PdfWordAnchor>[];
  final List<int> _globalWordAnchorIndices = <int>[];
  final List<String> _globalWords = <String>[];
  final List<String> _globalSurfaceWords = <String>[];
  final List<int> _paragraphWordStart = <int>[];
  List<String> _indexedParagraphs = const <String>[];
  int _activeReadAloudAnchorIndex = -1;
  int _pdfWordAnchorBuildId = 0;
  int _highlightRequestId = 0;
  int _searchRequestId = 0;
  bool _highlightSearchInFlight = false;
  bool _highlightRetryPending = false;
  int _pendingHighlightGlobalIndex = -1;
  final Map<String, int> _queryOccurrenceProgress = <String, int>{};
  String? _wordAnchorSourcePath;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfViewerController();
  }

  @override
  void dispose() {
    _highlightRequestId++;
    _searchRequestId++;
    _clearReadAloudAnnotations();
    _readAloudSearchResult?.clear();
    _pdfController?.dispose();
    _searchController.dispose();
    _searchResult?.clear();
    super.dispose();
  }

  String _normalizeExtractedPdfText(String text) {
    var normalized = text.replaceAll('\u00A0', ' ').replaceAll('\r', '\n');
    normalized = normalized.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');
    normalized = normalized.replaceAllMapped(
      RegExp(r'([.!?;:,])(?=[A-Za-z])'),
      (m) => '${m.group(1)} ',
    );
    // Defensive cleanup for legacy bad replacement artifacts like "$1".
    normalized = normalized.replaceAll(RegExp(r'\$[0-9]+'), ' ');
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

  bool _isPdfPath(String path) => p.extension(path).toLowerCase() == '.pdf';

  String _cleanWordForSearch(String word) {
    final cleaned = word.replaceAll(RegExp(r'[^\w]'), '');
    return cleaned.toLowerCase();
  }

  String _surfaceWordForSearch(String word) {
    var surface = word.trim();
    surface = surface.replaceAll(RegExp(r'^[^A-Za-z0-9]+'), '');
    surface = surface.replaceAll(RegExp(r'[^A-Za-z0-9]+$'), '');
    return surface;
  }

  List<String> _splitSentenceWords(String sentence) {
    return sentence
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => _cleanWordForSearch(w).length >= 2)
        .toList();
  }

  void _setWordAnchorSourcePath(String? sourcePath) {
    if (_wordAnchorSourcePath == sourcePath) return;
    _highlightRequestId++;
    _searchRequestId++;
    _wordAnchorSourcePath = sourcePath;
    _pdfWordAnchors.clear();
    _globalWordAnchorIndices
      ..clear()
      ..addAll(List<int>.filled(_globalWords.length, -1));
    _activeReadAloudAnchorIndex = -1;
    _pdfWordAnchorBuildId++;
    _queryOccurrenceProgress.clear();
    _pendingHighlightGlobalIndex = -1;
    _highlightRetryPending = false;
    _highlightSearchInFlight = false;
    _clearReadAloudSearchHighlight();
    _clearReadAloudAnnotations();
  }

  void _rebuildGlobalWordIndex(List<String> paragraphs) {
    if (listEquals(_indexedParagraphs, paragraphs)) return;
    _indexedParagraphs = List<String>.from(paragraphs);

    _globalWords.clear();
    _globalSurfaceWords.clear();
    _paragraphWordStart.clear();
    for (final paragraph in paragraphs) {
      _paragraphWordStart.add(_globalWords.length);
      final words = _splitSentenceWords(paragraph);
      for (final word in words) {
        final clean = _cleanWordForSearch(word);
        if (clean.length < 2) continue;
        final surface = _surfaceWordForSearch(word);
        if (surface.isEmpty) continue;
        _globalWords.add(clean);
        _globalSurfaceWords.add(surface);
      }
    }

    _globalWordAnchorIndices
      ..clear()
      ..addAll(List<int>.filled(_globalWords.length, -1));
    _queryOccurrenceProgress.clear();
    _buildGlobalWordAnchorMap();
  }

  Future<void> _preparePdfWordAnchorsIfNeeded(String sourcePath) async {
    if (!_isPdfPath(sourcePath)) return;
    if (_pdfWordAnchors.isNotEmpty) return;

    final file = File(sourcePath);
    if (!await file.exists()) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    final buildId = ++_pdfWordAnchorBuildId;
    final anchors = <_PdfWordAnchor>[];
    pdf.PdfDocument? document;
    try {
      document = pdf.PdfDocument(inputBytes: bytes);
      final extractor = pdf.PdfTextExtractor(document);
      final textLines = extractor.extractTextLines();

      for (final line in textLines) {
        final pageNumber = line.pageIndex + 1;
        for (final word in line.wordCollection) {
          final normalized = _cleanWordForSearch(word.text);
          if (normalized.length < 2) continue;
          anchors.add(
            _PdfWordAnchor(
              normalizedWord: normalized,
              line: PdfTextLine(word.bounds, word.text, pageNumber),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('TTS: Failed to build PDF word anchors: $e');
      return;
    } finally {
      document?.dispose();
    }

    if (!mounted ||
        buildId != _pdfWordAnchorBuildId ||
        _wordAnchorSourcePath != sourcePath) {
      return;
    }

    _pdfWordAnchors
      ..clear()
      ..addAll(anchors);
    _buildGlobalWordAnchorMap();
  }

  void _buildGlobalWordAnchorMap() {
    if (_globalWordAnchorIndices.length != _globalWords.length) {
      _globalWordAnchorIndices
        ..clear()
        ..addAll(List<int>.filled(_globalWords.length, -1));
    } else {
      for (var i = 0; i < _globalWordAnchorIndices.length; i++) {
        _globalWordAnchorIndices[i] = -1;
      }
    }

    if (_globalWords.isEmpty || _pdfWordAnchors.isEmpty) return;

    int anchorCursor = 0;
    for (int i = 0; i < _globalWords.length; i++) {
      final target = _globalWords[i];
      while (anchorCursor < _pdfWordAnchors.length &&
          _pdfWordAnchors[anchorCursor].normalizedWord != target) {
        anchorCursor++;
      }
      if (anchorCursor >= _pdfWordAnchors.length) break;
      _globalWordAnchorIndices[i] = anchorCursor;
      anchorCursor++;
    }
  }

  void _clearReadAloudAnnotations() {
    final controller = _pdfController;
    if (controller == null) return;

    final stale = <Annotation>[..._activeReadAloudAnnotations];
    try {
      final existing = controller.getAnnotations();
      for (final annotation in existing) {
        if ((annotation.subject ?? '') == 'mayari.readaloud') {
          stale.add(annotation);
        }
      }
    } catch (_) {
      // Viewer may not be ready for annotation enumeration.
    }

    for (final annotation in stale.toSet()) {
      try {
        controller.removeAnnotation(annotation);
      } catch (_) {
        // Ignore stale references during rapid updates.
      }
    }

    _activeReadAloudAnnotations.clear();
    _activeReadAloudAnchorIndex = -1;
  }

  void _clearReadAloudSearchHighlight() {
    _readAloudSearchResult?.clear();
    _readAloudSearchResult = null;
  }

  bool _tryHighlightWithPdfWordAnchor(int globalIndex) {
    final controller = _pdfController;
    if (controller == null) return false;
    if (globalIndex < 0 || globalIndex >= _globalWordAnchorIndices.length) {
      return false;
    }

    final indices = <int>[];
    for (int offset = 2; offset >= 0; offset--) {
      final idx = globalIndex - offset;
      if (idx < 0 || idx >= _globalWordAnchorIndices.length) continue;
      final anchorIndex = _globalWordAnchorIndices[idx];
      if (anchorIndex < 0 || anchorIndex >= _pdfWordAnchors.length) continue;
      indices.add(anchorIndex);
    }
    if (indices.isEmpty) return false;

    final currentAnchorIndex = indices.last;
    if (_activeReadAloudAnchorIndex == currentAnchorIndex &&
        _activeReadAloudAnnotations.length == indices.length) {
      return true;
    }

    _clearReadAloudSearchHighlight();
    _clearReadAloudAnnotations();
    for (int i = 0; i < indices.length; i++) {
      final anchor = _pdfWordAnchors[indices[i]];
      final isCurrentWord = i == indices.length - 1;
      final annotation =
          HighlightAnnotation(textBoundsCollection: [anchor.line])
            ..subject = 'mayari.readaloud'
            ..author = 'mayari'
            ..color = isCurrentWord
                ? _activeReadAloudHighlightColor
                : _trailingReadAloudHighlightColor
            ..opacity = isCurrentWord ? 0.82 : 0.55;
      controller.addAnnotation(annotation);
      _activeReadAloudAnnotations.add(annotation);
    }
    _activeReadAloudAnchorIndex = currentAnchorIndex;

    final currentAnchor = _pdfWordAnchors[currentAnchorIndex];
    if (controller.pageNumber != currentAnchor.line.pageNumber) {
      controller.jumpToPage(currentAnchor.line.pageNumber);
    }

    return true;
  }

  List<_SearchQueryCandidate> _buildSearchCandidates(int globalIndex) {
    if (_globalWords.isEmpty ||
        _globalSurfaceWords.length != _globalWords.length ||
        globalIndex < 0 ||
        globalIndex >= _globalWords.length) {
      return const [];
    }

    final candidates = <_SearchQueryCandidate>[];
    final seenQueries = <String>{};

    void addCandidate(int leftContextWords, int rightContextWords) {
      final start = globalIndex - leftContextWords;
      final end = globalIndex + rightContextWords + 1;
      if (start < 0 || end > _globalWords.length || start >= end) return;

      final normalizedTokens = _globalWords.sublist(start, end);
      final surfaceTokens = _globalSurfaceWords.sublist(start, end);
      if (normalizedTokens.length < 3 || surfaceTokens.isEmpty) return;

      final query = surfaceTokens.join(' ');
      if (query.length < 3 || !seenQueries.add(query)) return;

      final expected = _countSequenceOccurrences(
        normalizedTokens,
        uptoStart: start,
      );
      final totalExpected = _countSequenceOccurrences(normalizedTokens);

      candidates.add(
        _SearchQueryCandidate(
          query: query,
          expectedOccurrence: expected,
          totalExpectedOccurrences: totalExpected,
          tokenCount: normalizedTokens.length,
        ),
      );
    }

    addCandidate(1, 1);
    addCandidate(8, 8);
    addCandidate(7, 7);
    addCandidate(6, 6);
    addCandidate(5, 5);
    addCandidate(4, 4);
    addCandidate(3, 3);
    addCandidate(2, 2);
    addCandidate(0, 4);
    addCandidate(4, 0);
    addCandidate(0, 3);
    addCandidate(3, 0);
    addCandidate(1, 3);
    addCandidate(3, 1);

    return candidates;
  }

  int _countSequenceOccurrences(List<String> sequence, {int? uptoStart}) {
    if (sequence.isEmpty || _globalWords.length < sequence.length) return 0;

    int count = 0;
    final lastStart = _globalWords.length - sequence.length;
    final cappedEnd = uptoStart == null
        ? lastStart
        : uptoStart.clamp(0, lastStart);

    for (int i = 0; i <= cappedEnd; i++) {
      bool isMatch = true;
      for (int j = 0; j < sequence.length; j++) {
        if (_globalWords[i + j] != sequence[j]) {
          isMatch = false;
          break;
        }
      }
      if (isMatch) count++;
    }

    return count;
  }

  int _countWordOccurrences(String normalizedWord, {int? uptoIndex}) {
    if (normalizedWord.isEmpty || _globalWords.isEmpty) return 0;

    int count = 0;
    final endIndex = uptoIndex == null
        ? _globalWords.length - 1
        : uptoIndex.clamp(0, _globalWords.length - 1);

    for (int i = 0; i <= endIndex; i++) {
      if (_globalWords[i] == normalizedWord) {
        count++;
      }
    }

    return count;
  }

  int _resolveDesiredOccurrence({
    required int desiredOccurrence,
    required int expectedTotalOccurrences,
    required int actualTotalOccurrences,
    int? previousDesiredOccurrence,
  }) {
    var desired = desiredOccurrence;
    if (desired <= 0) desired = 1;

    if (desired > actualTotalOccurrences && expectedTotalOccurrences > 0) {
      final ratio = desired / expectedTotalOccurrences;
      desired = (ratio * actualTotalOccurrences).round();
    }

    if (previousDesiredOccurrence != null &&
        desired < previousDesiredOccurrence) {
      desired = previousDesiredOccurrence;
    }

    return desired.clamp(1, actualTotalOccurrences);
  }

  void _seekToSearchOccurrence(
    PdfTextSearchResult result,
    int desiredOccurrence,
    int totalOccurrences,
  ) {
    int safety = 0;
    while (result.currentInstanceIndex != desiredOccurrence &&
        safety < totalOccurrences) {
      result.nextInstance();
      safety++;
    }
  }

  Future<_SearchWaitOutcome> _waitForSearchCompletion(
    PdfTextSearchResult result,
    int requestId, {
    Duration timeout = const Duration(milliseconds: 2000),
  }) {
    final completer = Completer<_SearchWaitOutcome>();
    late VoidCallback listener;
    Timer? timer;
    final initialHasResult = result.hasResult;
    final initialTotal = result.totalInstanceCount;
    final initialCurrent = result.currentInstanceIndex;
    final initialCompleted = result.isSearchCompleted;
    bool hasStateChange = false;

    bool hasUsableMatch() =>
        result.hasResult &&
        result.totalInstanceCount > 0 &&
        result.currentInstanceIndex > 0;

    _SearchWaitOutcome evaluate() {
      if (!hasStateChange) return _SearchWaitOutcome.unavailable;
      if (hasUsableMatch()) return _SearchWaitOutcome.matched;
      if (result.isSearchCompleted) return _SearchWaitOutcome.noMatch;
      return _SearchWaitOutcome.unavailable;
    }

    void finish(_SearchWaitOutcome outcome) {
      if (completer.isCompleted) return;
      timer?.cancel();
      result.removeListener(listener);
      completer.complete(outcome);
    }

    listener = () {
      if (requestId != _searchRequestId) {
        finish(_SearchWaitOutcome.superseded);
        return;
      }
      if (!hasStateChange &&
          (result.hasResult != initialHasResult ||
              result.totalInstanceCount != initialTotal ||
              result.currentInstanceIndex != initialCurrent ||
              result.isSearchCompleted != initialCompleted)) {
        hasStateChange = true;
      }
      final outcome = evaluate();
      if (outcome == _SearchWaitOutcome.matched ||
          outcome == _SearchWaitOutcome.noMatch) {
        finish(outcome);
      }
    };

    result.addListener(listener);
    timer = Timer(timeout, () => finish(evaluate()));

    return completer.future;
  }

  Future<bool> _trySearchCandidate(
    _SearchQueryCandidate candidate,
    int requestId,
  ) async {
    final controller = _pdfController;
    if (controller == null) return false;
    if (requestId != _searchRequestId) return false;
    if (candidate.tokenCount < 3) return false;

    Future<({PdfTextSearchResult? result, _SearchWaitOutcome outcome})>
    runSearch({required bool wholeWords}) async {
      if (requestId != _searchRequestId) {
        return (result: null, outcome: _SearchWaitOutcome.superseded);
      }
      final result = wholeWords
          ? controller.searchText(
              candidate.query,
              searchOption: pdf.TextSearchOption.wholeWords,
            )
          : controller.searchText(candidate.query);
      final outcome = await _waitForSearchCompletion(result, requestId);
      if (requestId != _searchRequestId) {
        return (result: null, outcome: _SearchWaitOutcome.superseded);
      }
      if (outcome != _SearchWaitOutcome.matched) {
        return (result: null, outcome: outcome);
      }
      if (!result.hasResult ||
          result.totalInstanceCount <= 0 ||
          result.currentInstanceIndex <= 0) {
        return (result: null, outcome: _SearchWaitOutcome.noMatch);
      }
      return (result: result, outcome: outcome);
    }

    final firstAttempt = await runSearch(wholeWords: true);
    if (firstAttempt.outcome == _SearchWaitOutcome.superseded ||
        firstAttempt.outcome == _SearchWaitOutcome.unavailable) {
      return false;
    }

    PdfTextSearchResult? result = firstAttempt.result;
    if (result == null) {
      final secondAttempt = await runSearch(wholeWords: false);
      if (secondAttempt.outcome == _SearchWaitOutcome.superseded ||
          secondAttempt.outcome == _SearchWaitOutcome.unavailable) {
        return false;
      }
      result = secondAttempt.result;
    }
    if (result == null) return false;
    _readAloudSearchResult = result;

    final total = result.totalInstanceCount;
    final previousDesired = _queryOccurrenceProgress[candidate.query];
    final desired = _resolveDesiredOccurrence(
      desiredOccurrence: candidate.expectedOccurrence,
      expectedTotalOccurrences: candidate.totalExpectedOccurrences,
      actualTotalOccurrences: total,
      previousDesiredOccurrence: previousDesired,
    );

    _seekToSearchOccurrence(result, desired, total);
    _queryOccurrenceProgress[candidate.query] = desired;
    return true;
  }

  Future<bool> _tryHighlightExactWord(int globalIndex, int requestId) async {
    final controller = _pdfController;
    if (controller == null) return false;
    if (requestId != _searchRequestId) return false;
    if (globalIndex < 0 || globalIndex >= _globalWords.length) return false;
    if (_globalSurfaceWords.length != _globalWords.length) return false;

    final normalizedWord = _globalWords[globalIndex];
    if (normalizedWord.length < 2) return false;

    final surfaceWord = _globalSurfaceWords[globalIndex];
    final queries = <String>{
      if (surfaceWord.length >= 2) surfaceWord,
      normalizedWord,
      if (normalizedWord.isNotEmpty)
        '${normalizedWord[0].toUpperCase()}${normalizedWord.substring(1)}',
    };

    for (final query in queries) {
      if (requestId != _searchRequestId) return false;

      for (final wholeWords in [true, false]) {
        if (requestId != _searchRequestId) return false;

        final result = wholeWords
            ? controller.searchText(
                query,
                searchOption: pdf.TextSearchOption.wholeWords,
              )
            : controller.searchText(query);
        final outcome = await _waitForSearchCompletion(result, requestId);
        if (requestId != _searchRequestId ||
            outcome == _SearchWaitOutcome.superseded) {
          return false;
        }
        if (outcome == _SearchWaitOutcome.unavailable) {
          return false;
        }
        if (outcome != _SearchWaitOutcome.matched ||
            !result.hasResult ||
            result.totalInstanceCount <= 0 ||
            result.currentInstanceIndex <= 0) {
          continue;
        }

        final expectedOccurrence = _countWordOccurrences(
          normalizedWord,
          uptoIndex: globalIndex,
        );
        final expectedTotal = _countWordOccurrences(normalizedWord);
        final progressKey = 'word::$normalizedWord';
        final previousDesired = _queryOccurrenceProgress[progressKey];
        final desired = _resolveDesiredOccurrence(
          desiredOccurrence: expectedOccurrence,
          expectedTotalOccurrences: expectedTotal,
          actualTotalOccurrences: result.totalInstanceCount,
          previousDesiredOccurrence: previousDesired,
        );

        _seekToSearchOccurrence(result, desired, result.totalInstanceCount);
        _readAloudSearchResult = result;
        _queryOccurrenceProgress[progressKey] = desired;
        return true;
      }
    }

    return false;
  }

  Future<void> _performHighlightGlobalWord(
    int globalIndex,
    int requestId,
  ) async {
    if (requestId != _searchRequestId) return;
    if (globalIndex < 0 || globalIndex >= _globalWords.length) return;
    if (_globalWords[globalIndex].isEmpty) return;

    if (_pdfWordAnchors.isNotEmpty &&
        _tryHighlightWithPdfWordAnchor(globalIndex)) {
      return;
    }

    final exactWordMatched = await _tryHighlightExactWord(
      globalIndex,
      requestId,
    );
    if (exactWordMatched) return;

    final candidates = _buildSearchCandidates(globalIndex);
    if (candidates.isEmpty) return;

    for (final candidate in candidates) {
      if (requestId != _searchRequestId) return;
      final matched = await _trySearchCandidate(candidate, requestId);
      if (matched) return;
    }
  }

  Future<void> _highlightGlobalWord(int globalIndex) async {
    if (_highlightSearchInFlight) {
      _highlightRetryPending = true;
      _pendingHighlightGlobalIndex = globalIndex;
      return;
    }

    _highlightSearchInFlight = true;
    _pendingHighlightGlobalIndex = globalIndex;
    try {
      do {
        _highlightRetryPending = false;
        final requestId = ++_searchRequestId;
        await _performHighlightGlobalWord(
          _pendingHighlightGlobalIndex,
          requestId,
        );
      } while (_highlightRetryPending);
    } finally {
      _highlightSearchInFlight = false;
      _highlightRetryPending = false;
    }
  }

  Future<void> _highlightCurrentTtsWord({
    required String sourcePath,
    required int globalWordIndex,
    required int requestId,
  }) async {
    if (requestId != _highlightRequestId) return;
    await _preparePdfWordAnchorsIfNeeded(sourcePath);
    if (requestId != _highlightRequestId) return;
    await _highlightGlobalWord(globalWordIndex);
  }

  void _handleTtsStateChanged(TtsState next) {
    final activeSource = ref.read(activeSourceProvider);
    final sourcePath = activeSource?.filePath;
    if (sourcePath == null || !_isPdfPath(sourcePath)) {
      _setWordAnchorSourcePath(null);
      return;
    }

    _setWordAnchorSourcePath(sourcePath);
    _rebuildGlobalWordIndex(next.paragraphs);

    if (next.isStopped || !next.isPlaying || next.currentWordIndex < 0) {
      if (next.isStopped) {
        _highlightRequestId++;
        _searchRequestId++;
        _queryOccurrenceProgress.clear();
        _pendingHighlightGlobalIndex = -1;
        _highlightRetryPending = false;
        _clearReadAloudSearchHighlight();
        _clearReadAloudAnnotations();
      }
      return;
    }

    if (next.currentParagraphIndex < 0 ||
        next.currentParagraphIndex >= _paragraphWordStart.length) {
      return;
    }

    final paragraphWords = _splitSentenceWords(
      next.paragraphs[next.currentParagraphIndex],
    );
    if (next.currentWordIndex >= paragraphWords.length) {
      return;
    }

    final globalIndex =
        _paragraphWordStart[next.currentParagraphIndex] + next.currentWordIndex;
    if (globalIndex < 0 || globalIndex >= _globalWords.length) return;

    final requestId = ++_highlightRequestId;
    unawaited(
      _highlightCurrentTtsWord(
        sourcePath: sourcePath,
        globalWordIndex: globalIndex,
        requestId: requestId,
      ),
    );
  }

  String _extractPdfTextLocally(Uint8List bytes, int startPage) {
    final document = pdf.PdfDocument(inputBytes: bytes);
    try {
      final extractor = pdf.PdfTextExtractor(document);
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
          startPage: currentPage,
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
    final source = await ref
        .read(sourcesProvider.notifier)
        .ensureSourceForFile(filePath);

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
    ref.listen<TtsState>(ttsProvider, (previous, next) {
      _handleTtsStateChanged(next);
    });

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
                    _setWordAnchorSourcePath(activeSource.filePath);
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
                  },
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
        const TtsReadingIndicator(),
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
    final modelStatus = ref.watch(modelDownloadProvider);

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
            // Model status indicator and download button
            _buildModelStatusIndicator(modelStatus),
            const SizedBox(width: 2),
            // TTS Controls (disabled if model not ready)
            _buildTtsPlayButton(ttsState, ttsNotifier, modelStatus),
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
            IconButton(
              icon: const Icon(Icons.skip_previous, size: 16),
              onPressed:
                  (!modelStatus.isReady || ttsState.currentParagraphIndex <= 0)
                  ? null
                  : () => ttsNotifier.skipBackward(),
              tooltip: 'Previous chunk',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
            IconButton(
              icon: const Icon(Icons.skip_next, size: 16),
              onPressed:
                  (!modelStatus.isReady ||
                      ttsState.currentParagraphIndex >=
                          ttsState.totalParagraphs - 1)
                  ? null
                  : () => ttsNotifier.skipForward(),
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
            _buildSpeedSlider(ttsState, ttsNotifier),
            const SizedBox(width: 8),
            // Create Audiobook button
            _buildAudiobookButton(modelStatus),
            const SizedBox(width: 8),
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
            const SizedBox(width: 4),
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
            divisions: 150, // 0.01 increments
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

  Widget _buildAudiobookButton(ModelDownloadStatus modelStatus) {
    final activeSource = ref.watch(activeSourceProvider);

    return OutlinedButton.icon(
      onPressed: (!modelStatus.isReady || activeSource == null)
          ? null
          : () => _handleCreateAudiobook(),
      icon: const Icon(Icons.audiotrack, size: 16),
      label: const Text('Create Audiobook'),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStyle: const TextStyle(fontSize: 12),
      ),
    );
  }

  Future<void> _handleCreateAudiobook() async {
    final activeSource = ref.read(activeSourceProvider);
    final ttsState = ref.read(ttsProvider);
    if (activeSource == null) return;

    // Extract all text from PDF
    final file = File(activeSource.filePath);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PDF file not found')));
      }
      return;
    }
    try {
      final handle = file.openSync(mode: FileMode.read);
      handle.closeSync();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cannot access this PDF. Use Open Folder and grant permission.',
            ),
          ),
        );
      }
      return;
    }

    setState(() => _isExtractingTextForTts = true);

    try {
      final bytes = await file.readAsBytes();
      final document = pdf.PdfDocument(inputBytes: bytes);
      final chunks = <String>[];

      // Extract text from each page
      for (int i = 0; i < document.pages.count; i++) {
        final text = pdf.PdfTextExtractor(
          document,
        ).extractText(startPageIndex: i, endPageIndex: i);
        final normalized = _normalizeExtractedPdfText(text);
        if (normalized.isNotEmpty) {
          // Split into paragraphs
          final paragraphs = normalized.split(RegExp(r'\n\s*\n'));
          for (final para in paragraphs) {
            final trimmed = para.trim();
            if (trimmed.isNotEmpty && trimmed.length > 10) {
              chunks.add(trimmed);
            }
          }
        }
      }

      document.dispose();

      setState(() => _isExtractingTextForTts = false);

      if (chunks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('No text found in PDF')));
        }
        return;
      }

      await ref
          .read(audiobookJobsProvider.notifier)
          .enqueue(
            title: activeSource.title,
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
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isExtractingTextForTts = false);
      if (mounted) {
        final message = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.contains('PathAccessException')
                  ? 'PDF access denied. Re-open the folder and allow access.'
                  : 'Error extracting text: $e',
            ),
          ),
        );
      }
    }
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
