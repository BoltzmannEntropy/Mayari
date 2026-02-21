import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ExampleDocumentSeed {
  const ExampleDocumentSeed({
    required this.assetPath,
    required this.fileName,
    required this.title,
    required this.author,
    required this.year,
    this.publisher,
  });

  final String assetPath;
  final String fileName;
  final String title;
  final String author;
  final int year;
  final String? publisher;
}

class ExampleAudiobookSeed {
  const ExampleAudiobookSeed({
    required this.assetPath,
    required this.fileName,
    required this.title,
    required this.voice,
    required this.speed,
    required this.chunks,
    required this.durationSeconds,
  });

  final String assetPath;
  final String fileName;
  final String title;
  final String voice;
  final double speed;
  final int chunks;
  final double durationSeconds;
}

class LoadedExampleDocument {
  const LoadedExampleDocument({
    required this.path,
    required this.title,
    required this.author,
    required this.year,
    this.publisher,
  });

  final String path;
  final String title;
  final String author;
  final int year;
  final String? publisher;
}

class LoadedExampleAudiobook {
  const LoadedExampleAudiobook({
    required this.path,
    required this.title,
    required this.voice,
    required this.speed,
    required this.chunks,
    required this.durationSeconds,
  });

  final String path;
  final String title;
  final String voice;
  final double speed;
  final int chunks;
  final double durationSeconds;
}

class LoadedExamplesBundle {
  const LoadedExamplesBundle({
    required this.documentsDirectory,
    required this.documents,
    required this.audiobooks,
  });

  final String documentsDirectory;
  final List<LoadedExampleDocument> documents;
  final List<LoadedExampleAudiobook> audiobooks;
}

class ExamplesLoaderService {
  static const List<ExampleDocumentSeed> _documentSeeds = [
    ExampleDocumentSeed(
      assetPath: 'assets/examples/documents/example_pdf_genesis.pdf',
      fileName: 'example_pdf_genesis.pdf',
      title: 'Genesis Chapter 1 (PDF)',
      author: 'King James Version',
      year: 1611,
      publisher: 'Public Domain',
    ),
    ExampleDocumentSeed(
      assetPath: 'assets/examples/documents/example_docx_readaloud.docx',
      fileName: 'example_docx_readaloud.docx',
      title: 'Mayari DOCX Read Aloud Sample',
      author: 'Mayari Team',
      year: 2026,
      publisher: 'Mayari Examples',
    ),
    ExampleDocumentSeed(
      assetPath: 'assets/examples/documents/example_epub_readaloud.epub',
      fileName: 'example_epub_readaloud.epub',
      title: 'Mayari EPUB Read Aloud Sample',
      author: 'Mayari Team',
      year: 2026,
      publisher: 'Mayari Examples',
    ),
  ];

  static const List<ExampleAudiobookSeed> _audiobookSeeds = [
    ExampleAudiobookSeed(
      assetPath: 'assets/examples/audiobooks/example_pdf_genesis.wav',
      fileName: 'example_pdf_genesis.wav',
      title: 'Example Audiobook - PDF',
      voice: 'bf_emma',
      speed: 1.0,
      chunks: 1,
      durationSeconds: 15.1,
    ),
    ExampleAudiobookSeed(
      assetPath: 'assets/examples/audiobooks/example_docx_readaloud.wav',
      fileName: 'example_docx_readaloud.wav',
      title: 'Example Audiobook - DOCX',
      voice: 'af_heart',
      speed: 1.0,
      chunks: 1,
      durationSeconds: 16.7,
    ),
    ExampleAudiobookSeed(
      assetPath: 'assets/examples/audiobooks/example_epub_readaloud.wav',
      fileName: 'example_epub_readaloud.wav',
      title: 'Example Audiobook - EPUB',
      voice: 'bm_fable',
      speed: 1.0,
      chunks: 1,
      durationSeconds: 15.0,
    ),
  ];

  Future<LoadedExamplesBundle> loadExamples() async {
    final baseDir = await _ensureExamplesBaseDir();
    final docsDir = Directory(p.join(baseDir.path, 'documents'));
    final audioDir = Directory(p.join(baseDir.path, 'audiobooks'));
    if (!docsDir.existsSync()) {
      docsDir.createSync(recursive: true);
    }
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }

    final loadedDocs = <LoadedExampleDocument>[];
    for (final seed in _documentSeeds) {
      final path = await _copyAsset(
        seed.assetPath,
        p.join(docsDir.path, seed.fileName),
      );
      loadedDocs.add(
        LoadedExampleDocument(
          path: path,
          title: seed.title,
          author: seed.author,
          year: seed.year,
          publisher: seed.publisher,
        ),
      );
    }

    final loadedAudiobooks = <LoadedExampleAudiobook>[];
    for (final seed in _audiobookSeeds) {
      final path = await _copyAsset(
        seed.assetPath,
        p.join(audioDir.path, seed.fileName),
      );
      loadedAudiobooks.add(
        LoadedExampleAudiobook(
          path: path,
          title: seed.title,
          voice: seed.voice,
          speed: seed.speed,
          chunks: seed.chunks,
          durationSeconds: seed.durationSeconds,
        ),
      );
    }

    return LoadedExamplesBundle(
      documentsDirectory: docsDir.path,
      documents: loadedDocs,
      audiobooks: loadedAudiobooks,
    );
  }

  Future<Directory> _ensureExamplesBaseDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final examplesDir = Directory(p.join(supportDir.path, 'examples'));
    if (!examplesDir.existsSync()) {
      examplesDir.createSync(recursive: true);
    }
    return examplesDir;
  }

  Future<String> _copyAsset(String assetPath, String destinationPath) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List(
      byteData.offsetInBytes,
      byteData.lengthInBytes,
    );
    final file = File(destinationPath);
    await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
    return file.path;
  }
}
