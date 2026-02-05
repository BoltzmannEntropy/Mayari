import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/source.dart';
import '../models/quote.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider((ref) => StorageService());

final sourcesProvider =
    StateNotifierProvider<SourcesNotifier, List<Source>>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return SourcesNotifier(storage);
});

final activeSourceIdProvider = StateProvider<String?>((ref) => null);

final activeSourceProvider = Provider<Source?>((ref) {
  final sources = ref.watch(sourcesProvider);
  final activeId = ref.watch(activeSourceIdProvider);
  if (activeId == null) return null;
  try {
    return sources.firstWhere((s) => s.id == activeId);
  } catch (_) {
    return null;
  }
});

class SourcesNotifier extends StateNotifier<List<Source>> {
  final StorageService _storage;
  final _uuid = const Uuid();

  SourcesNotifier(this._storage) : super([]) {
    _loadSources();
  }

  Future<void> _loadSources() async {
    final loaded = await _storage.loadSources();
    final deduped = _dedupeSources(loaded);
    state = deduped.sources;
    if (deduped.didChange) {
      await _save();
    }
  }

  Future<void> _save() async {
    await _storage.saveSources(state);
  }

  Future<Source> addSource({
    required String title,
    required String author,
    required int year,
    String? publisher,
    required String filePath,
  }) async {
    final source = Source(
      id: _uuid.v4(),
      title: title,
      author: author,
      year: year,
      publisher: publisher,
      filePath: filePath,
      createdAt: DateTime.now(),
    );
    state = [...state, source];
    await _save();
    return source;
  }

  Future<void> updateSource(Source source) async {
    state = state.map((s) => s.id == source.id ? source : s).toList();
    await _save();
  }

  Future<void> removeSource(String sourceId) async {
    state = state.where((s) => s.id != sourceId).toList();
    await _save();
  }

  Future<bool> addQuote({
    required String sourceId,
    required String text,
    required int pageNumber,
    String? notes,
  }) async {
    final normalizedText = _normalizeQuoteText(text);
    if (normalizedText.isEmpty) return false;

    final source = state.firstWhere((s) => s.id == sourceId);
    final alreadyExists = source.quotes.any(
      (q) =>
          _normalizeQuoteText(q.text) == normalizedText &&
          q.pageNumber == pageNumber,
    );

    if (alreadyExists) return false;

    final quote = Quote(
      id: _uuid.v4(),
      sourceId: sourceId,
      text: text.trim(),
      pageNumber: pageNumber,
      notes: notes,
      createdAt: DateTime.now(),
      order: _getNextOrder(sourceId),
    );

    state = state.map((s) {
      if (s.id == sourceId) {
        return s.copyWith(quotes: [...s.quotes, quote]);
      }
      return s;
    }).toList();
    await _save();
    return true;
  }

  int _getNextOrder(String sourceId) {
    final source = state.firstWhere((s) => s.id == sourceId);
    if (source.quotes.isEmpty) return 0;
    return source.quotes.map((q) => q.order).reduce((a, b) => a > b ? a : b) + 1;
  }

  Future<void> updateQuote(Quote quote) async {
    state = state.map((s) {
      if (s.id == quote.sourceId) {
        return s.copyWith(
          quotes: s.quotes.map((q) => q.id == quote.id ? quote : q).toList(),
        );
      }
      return s;
    }).toList();
    await _save();
  }

  Future<void> removeQuote(String sourceId, String quoteId) async {
    state = state.map((s) {
      if (s.id == sourceId) {
        return s.copyWith(
          quotes: s.quotes.where((q) => q.id != quoteId).toList(),
        );
      }
      return s;
    }).toList();
    await _save();
  }

  Future<void> reorderQuotes(String sourceId, int oldIndex, int newIndex) async {
    state = state.map((s) {
      if (s.id == sourceId) {
        final quotes = List.of(s.quotes);
        final quote = quotes.removeAt(oldIndex);
        quotes.insert(newIndex, quote);
        for (int i = 0; i < quotes.length; i++) {
          quotes[i] = quotes[i].copyWith(order: i);
        }
        return s.copyWith(quotes: quotes);
      }
      return s;
    }).toList();
    await _save();
  }

  String _normalizeQuoteText(String text) {
    return text.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  _DedupeResult _dedupeSources(List<Source> sources) {
    var didChange = false;

    final updated = sources.map((source) {
      var sourceChanged = false;
      final quotesByOrder = List<Quote>.from(source.quotes)
        ..sort((a, b) => a.order.compareTo(b.order));

      final seen = <String>{};
      final deduped = <Quote>[];

      for (final quote in quotesByOrder) {
        final key =
            '${_normalizeQuoteText(quote.text)}::${quote.pageNumber}';
        if (seen.add(key)) {
          deduped.add(quote);
        } else {
          sourceChanged = true;
        }
      }

      final reindexed = <Quote>[];
      for (var i = 0; i < deduped.length; i++) {
        final quote = deduped[i];
        if (quote.order != i) {
          reindexed.add(quote.copyWith(order: i));
          sourceChanged = true;
        } else {
          reindexed.add(quote);
        }
      }

      if (reindexed.length != source.quotes.length) {
        sourceChanged = true;
      }

      if (sourceChanged) {
        didChange = true;
        return source.copyWith(quotes: reindexed);
      }
      return source;
    }).toList();

    return _DedupeResult(updated, didChange);
  }
}

class _DedupeResult {
  final List<Source> sources;
  final bool didChange;

  const _DedupeResult(this.sources, this.didChange);
}
