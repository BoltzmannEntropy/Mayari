import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

// Default PDF folder for development
const _defaultPdfFolder = '/Volumes/SSD4tb/Dropbox/DSS/artifacts/code/Mayari/pdf';

final libraryFolderProvider = StateProvider<String?>((ref) {
  // Check if default folder exists
  final dir = Directory(_defaultPdfFolder);
  final exists = dir.existsSync();
  print('Library: Default folder $_defaultPdfFolder exists: $exists');
  if (exists) {
    return _defaultPdfFolder;
  }
  return null;
});

final pdfFilesProvider = Provider<List<FileSystemEntity>>((ref) {
  final folderPath = ref.watch(libraryFolderProvider);
  print('Library: pdfFilesProvider called with folderPath: $folderPath');
  if (folderPath == null) return [];

  final directory = Directory(folderPath);
  if (!directory.existsSync()) {
    print('Library: Directory does not exist: $folderPath');
    return [];
  }

  try {
    final allFiles = directory.listSync();
    print('Library: Found ${allFiles.length} items in directory');
    for (final f in allFiles) {
      print('Library: - ${f.path} (isFile: ${f is File}, ext: ${p.extension(f.path)})');
    }
    final files = allFiles
        .where((f) => f is File && p.extension(f.path).toLowerCase() == '.pdf')
        .toList();
    print('Library: Filtered to ${files.length} PDF files');
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  } catch (e) {
    print('Library: Error listing directory: $e');
    return [];
  }
});
