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
    state = await _storage.loadSources();
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

  Future<void> addQuote({
    required String sourceId,
    required String text,
    required int pageNumber,
    String? notes,
  }) async {
    final quote = Quote(
      id: _uuid.v4(),
      sourceId: sourceId,
      text: text,
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
}
