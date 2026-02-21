import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:mayari/services/document_format.dart';
import 'package:mayari/services/document_text_extractor.dart';

void main() {
  final extractor = DocumentTextExtractor();
  final docsDir = p.join(
    Directory.current.path,
    'assets',
    'examples',
    'documents',
  );

  test('extracts text from sample DOCX', () async {
    final path = p.join(docsDir, 'example_docx_readaloud.docx');
    final result = await extractor.extractFromFile(path);

    expect(result.type, SupportedDocumentType.docx);
    expect(
      result.plainText.toLowerCase(),
      contains('read aloud support for docx'),
    );
    expect(result.paragraphs, isNotEmpty);
  });

  test('extracts text from sample EPUB', () async {
    final path = p.join(docsDir, 'example_epub_readaloud.epub');
    final result = await extractor.extractFromFile(path);

    expect(result.type, SupportedDocumentType.epub);
    expect(
      result.plainText.toLowerCase(),
      contains('validates epub extraction'),
    );
    expect(result.paragraphs.length, greaterThanOrEqualTo(2));
  });

  test('extracts text from sample PDF', () async {
    final path = p.join(docsDir, 'example_pdf_genesis.pdf');
    final result = await extractor.extractFromFile(path);
    final compact = result.plainText.toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );

    expect(result.type, SupportedDocumentType.pdf);
    expect(compact, contains('inthebeginning'));
    expect(result.paragraphs, isNotEmpty);
  });
}
