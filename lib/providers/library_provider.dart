import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

final libraryFolderProvider = StateProvider<String?>((ref) => null);

final pdfFilesProvider = Provider<List<FileSystemEntity>>((ref) {
  final folderPath = ref.watch(libraryFolderProvider);
  if (folderPath == null) return [];

  final directory = Directory(folderPath);
  if (!directory.existsSync()) return [];

  try {
    final files = directory
        .listSync()
        .where((f) => f is File && p.extension(f.path).toLowerCase() == '.pdf')
        .toList();
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  } catch (e) {
    return [];
  }
});
