import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

const _defaultPdfFolderEnv = 'MAYARI_DEFAULT_PDF_LIBRARY';
const _preferredDefaultPdfFolder =
    '/Volumes/SSD4tb/Dropbox/DSS/artifacts/code/MayariPRJ/MayariCODE/pdf';

bool _directoryHasPdf(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return false;
  try {
    return dir.listSync().any(
      (f) => f is File && p.extension(f.path).toLowerCase() == '.pdf',
    );
  } catch (_) {
    return false;
  }
}

/// Find the bundled PDF folder
String? _findBundledPdfFolder() {
  if (kIsWeb) return null;

  final candidates = <String>[];
  candidates.add(_preferredDefaultPdfFolder);

  if (Platform.isMacOS) {
    // macOS app bundle: Contents/Resources/pdf/
    final executable = Platform.resolvedExecutable;
    final contentsDir = p.dirname(p.dirname(executable));
    candidates.add(p.join(contentsDir, 'Resources', 'pdf'));

    // Development mode: project pdf/ folder
    var dir = Directory(p.dirname(executable));
    for (var i = 0; i < 10; i++) {
      candidates.add(p.join(dir.path, 'pdf'));
      dir = dir.parent;
    }

    // Hardcoded development path as fallback
    candidates.add(_preferredDefaultPdfFolder);
  }

  for (final path in candidates) {
    if (_directoryHasPdf(path)) {
      debugPrint('Found bundled PDF folder: $path');
      return path;
    }
  }

  return null;
}

final libraryFolderProvider = StateProvider<String?>((ref) {
  // Preferred development default folder
  if (_directoryHasPdf(_preferredDefaultPdfFolder)) {
    return _preferredDefaultPdfFolder;
  }

  // First check environment variable
  final configuredFolder = Platform.environment[_defaultPdfFolderEnv];
  if (configuredFolder != null &&
      configuredFolder.trim().isNotEmpty &&
      _directoryHasPdf(configuredFolder.trim())) {
    return configuredFolder.trim();
  }

  // Then try to find bundled PDF folder
  return _findBundledPdfFolder();
});

final pdfFilesProvider = Provider<List<FileSystemEntity>>((ref) {
  final folderPath = ref.watch(libraryFolderProvider);
  if (folderPath == null) return [];

  final directory = Directory(folderPath);
  if (!directory.existsSync()) {
    return [];
  }

  try {
    final allFiles = directory.listSync();
    final files = allFiles
        .where((f) => f is File && p.extension(f.path).toLowerCase() == '.pdf')
        .toList();
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  } catch (_) {
    return [];
  }
});
