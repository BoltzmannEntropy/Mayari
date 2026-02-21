import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../services/document_format.dart';

const _defaultLibraryEnv = 'MAYARI_DEFAULT_PDF_LIBRARY';

bool _isReadableDocumentFile(String filePath) {
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

bool _directoryHasSupportedDocuments(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return false;
  try {
    return dir.listSync().any(
      (f) =>
          f is File &&
          isSupportedDocumentPath(f.path) &&
          _isReadableDocumentFile(f.path),
    );
  } catch (_) {
    return false;
  }
}

String? _findBundledLibraryFolder() {
  if (kIsWeb) return null;

  final candidates = <String>[];

  if (Platform.isMacOS) {
    final executable = Platform.resolvedExecutable;
    final contentsDir = p.dirname(p.dirname(executable));
    candidates.add(p.join(contentsDir, 'Resources', 'pdf'));

    var dir = Directory(p.dirname(executable));
    for (var i = 0; i < 10; i++) {
      candidates.add(p.join(dir.path, 'pdf'));
      dir = dir.parent;
    }
  }

  for (final path in candidates) {
    if (_directoryHasSupportedDocuments(path)) {
      debugPrint('Found bundled document library: $path');
      return path;
    }
  }

  return null;
}

final libraryFolderProvider = StateProvider<String?>((ref) {
  final configuredFolder = Platform.environment[_defaultLibraryEnv];
  if (configuredFolder != null &&
      configuredFolder.trim().isNotEmpty &&
      _directoryHasSupportedDocuments(configuredFolder.trim())) {
    return configuredFolder.trim();
  }
  return _findBundledLibraryFolder();
});

final libraryFilesProvider = Provider<List<FileSystemEntity>>((ref) {
  final folderPath = ref.watch(libraryFolderProvider);
  if (folderPath == null) return [];

  final directory = Directory(folderPath);
  if (!directory.existsSync()) return [];

  try {
    final files = directory
        .listSync()
        .where((f) => f is File && isSupportedDocumentPath(f.path))
        .toList();
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  } catch (_) {
    return [];
  }
});

final pdfFilesProvider = Provider<List<FileSystemEntity>>((ref) {
  return ref
      .watch(libraryFilesProvider)
      .where((f) => p.extension(f.path).toLowerCase() == '.pdf')
      .toList();
});
