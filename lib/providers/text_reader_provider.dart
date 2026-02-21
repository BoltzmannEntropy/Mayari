import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/document_text_extractor.dart';

/// Default text content - Plato/Socrates quotes
const String defaultMarkdownText = '''
> "The mind is not a vessel to be filled, but a fire to be kindled."
>
> — Socrates, as quoted by Plutarch

And those who were seen dancing were thought to be insane by those who could not hear the music.

*True wisdom comes to each of us when we realize how little we understand about life, ourselves, and the world around us.*

---

## The Allegory of the Cave

Allegory of the Cave Allegory of the Cave Allegory of the Cave Allegory of the Cave Allegory of the Cave Allegory of the Cave

> "I cannot teach anybody anything. I can only make them think."
>
> — Socrates
''';

/// State for the text reader feature
class TextReaderState {
  final String markdownText;
  final bool isEditMode;
  final int currentParagraph;
  final List<String> paragraphs;
  final bool isLoadingDocument;
  final String? loadedDocumentPath;
  final String? loadedDocumentTitle;
  final String? documentError;

  const TextReaderState({
    this.markdownText = defaultMarkdownText,
    this.isEditMode = false,
    this.currentParagraph = 0,
    this.paragraphs = const [],
    this.isLoadingDocument = false,
    this.loadedDocumentPath,
    this.loadedDocumentTitle,
    this.documentError,
  });

  TextReaderState copyWith({
    String? markdownText,
    bool? isEditMode,
    int? currentParagraph,
    List<String>? paragraphs,
    bool? isLoadingDocument,
    String? loadedDocumentPath,
    String? loadedDocumentTitle,
    String? documentError,
    bool clearLoadedDocumentPath = false,
    bool clearLoadedDocumentTitle = false,
    bool clearDocumentError = false,
  }) {
    return TextReaderState(
      markdownText: markdownText ?? this.markdownText,
      isEditMode: isEditMode ?? this.isEditMode,
      currentParagraph: currentParagraph ?? this.currentParagraph,
      paragraphs: paragraphs ?? this.paragraphs,
      isLoadingDocument: isLoadingDocument ?? this.isLoadingDocument,
      loadedDocumentPath: clearLoadedDocumentPath
          ? null
          : (loadedDocumentPath ?? this.loadedDocumentPath),
      loadedDocumentTitle: clearLoadedDocumentTitle
          ? null
          : (loadedDocumentTitle ?? this.loadedDocumentTitle),
      documentError: clearDocumentError
          ? null
          : (documentError ?? this.documentError),
    );
  }

  /// Get plain text from markdown (strips markdown syntax for TTS)
  String get plainText {
    var text = markdownText;
    // Remove markdown headers
    text = text.replaceAll(RegExp(r'^#+\s+', multiLine: true), '');
    // Remove bold/italic markers
    text = text.replaceAll(RegExp(r'\*+'), '');
    text = text.replaceAll(RegExp(r'_+'), '');
    // Remove blockquote markers
    text = text.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    // Remove horizontal rules
    text = text.replaceAll(RegExp(r'^---+$', multiLine: true), '');
    // Remove links - keep text
    text = text.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1');
    // Remove code blocks
    text = text.replaceAll(RegExp(r'```[^`]*```'), '');
    text = text.replaceAll(RegExp(r'`([^`]+)`'), r'$1');
    // Clean up extra whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}

/// Notifier for text reader state management
class TextReaderNotifier extends StateNotifier<TextReaderState> {
  TextReaderNotifier() : super(const TextReaderState()) {
    _parseIntoParagraphs();
  }

  void _parseIntoParagraphs() {
    final plainText = state.plainText;
    final paragraphs = plainText
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    state = state.copyWith(paragraphs: paragraphs);
  }

  /// Set new markdown text content
  void setText(String text) {
    state = state.copyWith(
      markdownText: text,
      currentParagraph: 0,
      clearLoadedDocumentPath: true,
      clearLoadedDocumentTitle: true,
      clearDocumentError: true,
    );
    _parseIntoParagraphs();
  }

  void setTextFromDocument({
    required String text,
    required String path,
    required String title,
  }) {
    state = state.copyWith(
      markdownText: text,
      currentParagraph: 0,
      isEditMode: false,
      isLoadingDocument: false,
      loadedDocumentPath: path,
      loadedDocumentTitle: title,
      clearDocumentError: true,
    );
    _parseIntoParagraphs();
  }

  Future<void> loadDocument({
    required String path,
    required DocumentTextExtractor extractor,
  }) async {
    if (state.loadedDocumentPath == path && !state.isLoadingDocument) {
      return;
    }

    state = state.copyWith(
      isLoadingDocument: true,
      loadedDocumentPath: path,
      clearDocumentError: true,
    );
    try {
      final extracted = await extractor.extractFromFile(path);
      setTextFromDocument(
        text: extracted.plainText,
        path: path,
        title: extracted.title ?? extracted.path,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingDocument: false,
        loadedDocumentPath: path,
        documentError: e.toString(),
      );
    }
  }

  /// Toggle between view and edit mode
  void toggleEditMode() {
    state = state.copyWith(isEditMode: !state.isEditMode);
    if (!state.isEditMode) {
      // Exiting edit mode - re-parse paragraphs
      _parseIntoParagraphs();
    }
  }

  /// Set edit mode explicitly
  void setEditMode(bool editing) {
    state = state.copyWith(isEditMode: editing);
    if (!editing) {
      _parseIntoParagraphs();
    }
  }

  /// Reset to default text
  void resetToDefault() {
    state = state.copyWith(
      markdownText: defaultMarkdownText,
      currentParagraph: 0,
      isEditMode: false,
      isLoadingDocument: false,
      clearLoadedDocumentPath: true,
      clearLoadedDocumentTitle: true,
      clearDocumentError: true,
    );
    _parseIntoParagraphs();
  }

  /// Set current paragraph (for TTS highlighting)
  void setCurrentParagraph(int index) {
    if (index >= 0 && index < state.paragraphs.length) {
      state = state.copyWith(currentParagraph: index);
    }
  }
}

/// Provider for text reader state
final textReaderProvider =
    StateNotifierProvider<TextReaderNotifier, TextReaderState>((ref) {
      return TextReaderNotifier();
    });

/// Provider to track which content source is active
enum ContentSource { pdf, text }

final activeContentSourceProvider = StateProvider<ContentSource>((ref) {
  return ContentSource.pdf;
});
