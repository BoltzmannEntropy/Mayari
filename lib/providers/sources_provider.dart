import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../models/source.dart';
import '../services/storage_service.dart';

final storageServiceProvider = Provider((ref) => StorageService());

bool _isReadableFile(String filePath) {
  final file = File(filePath);
  if (!file.existsSync()) return false;
  try {
    final handle = file.openSync(mode: FileMode.read);
    handle.closeSync();
    return true;
  } catch (_) {
    return false;
  }
}

/// Callback to set active source after default PDF is loaded
typedef SetActiveSourceCallback = void Function(String sourceId);

final sourcesProvider = StateNotifierProvider<SourcesNotifier, List<Source>>((
  ref,
) {
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
  SetActiveSourceCallback? _onDefaultSourceLoaded;

  SourcesNotifier(this._storage) : super([]) {
    _loadSources();
  }

  /// Set callback to be called when default source is loaded
  void setOnDefaultSourceLoaded(SetActiveSourceCallback callback) {
    _onDefaultSourceLoaded = callback;
  }

  Future<void> _loadSources() async {
    final loaded = await _storage.loadSources();
    final valid = loaded.where((s) => _isReadableFile(s.filePath)).toList();
    state = valid;

    if (valid.length != loaded.length) {
      await _save();
    }

    // If no sources exist, try to load the bundled default PDF
    if (valid.isEmpty) {
      await _loadBundledDefaultPdf();
    }
  }

  /// Find and load the bundled genesis-chapter-1.pdf on first launch
  Future<void> _loadBundledDefaultPdf() async {
    final pdfPath = _findBundledPdf();
    if (pdfPath == null) {
      debugPrint('No bundled PDF found');
      return;
    }

    debugPrint('Found bundled PDF: $pdfPath');

    // Add it as the first source
    final source = await addSource(
      title: 'Genesis Chapter 1',
      author: 'King James Version',
      year: 1611,
      publisher: 'Public Domain',
      filePath: pdfPath,
    );

    // Notify to set as active source
    _onDefaultSourceLoaded?.call(source.id);
  }

  /// Find the bundled PDF in common locations
  String? _findBundledPdf() {
    const pdfName = 'genesis-chapter-1.pdf';

    // Candidate paths for the bundled PDF
    final candidates = <String>[];

    if (!kIsWeb && Platform.isMacOS) {
      // macOS app bundle: Contents/Resources/pdf/
      final executable = Platform.resolvedExecutable;
      final contentsDir = p.dirname(p.dirname(executable));
      candidates.add(p.join(contentsDir, 'Resources', 'pdf', pdfName));
      candidates.add(p.join(contentsDir, 'Resources', pdfName));

      // Development mode: project pdf/ folder (various locations)
      final current = Directory.current.path;
      candidates.add(p.join(current, 'pdf', pdfName));

      // Try to find from executable path going up
      var dir = Directory(p.dirname(executable));
      for (var i = 0; i < 10; i++) {
        final candidate = p.join(dir.path, 'pdf', pdfName);
        candidates.add(candidate);
        dir = dir.parent;
      }
    }

    debugPrint(
      'Searching for bundled PDF in ${candidates.length} locations...',
    );
    for (final path in candidates) {
      if (_isReadableFile(path)) {
        debugPrint('Found bundled PDF: $path');
        return path;
      }
    }

    debugPrint('Bundled PDF not found in any location');
    return null;
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

  /// Return existing source for a file, or create one with sensible defaults.
  Future<Source> ensureSourceForFile(String filePath) async {
    final existing = state.where((s) => s.filePath == filePath).firstOrNull;
    if (existing != null) return existing;

    return addSource(
      title: p.basenameWithoutExtension(filePath),
      author: 'Unknown Author',
      year: DateTime.now().year,
      publisher: null,
      filePath: filePath,
    );
  }

  Future<void> updateSource(Source source) async {
    state = state.map((s) => s.id == source.id ? source : s).toList();
    await _save();
  }

  Future<void> removeSource(String sourceId) async {
    state = state.where((s) => s.id != sourceId).toList();
    await _save();
  }
}
