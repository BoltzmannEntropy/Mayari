import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

const _defaultPdfFolderEnv = 'MAYARI_DEFAULT_PDF_LIBRARY';

final libraryFolderProvider = StateProvider<String?>((ref) {
  final configuredFolder = Platform.environment[_defaultPdfFolderEnv];
  if (configuredFolder == null || configuredFolder.trim().isEmpty) {
    return null;
  }
  final dir = Directory(configuredFolder.trim());
  if (dir.existsSync()) {
    return dir.path;
  }
  return null;
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
