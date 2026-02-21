import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import 'package:xml/xml.dart';

import 'document_format.dart';

class DocumentExtractionResult {
  const DocumentExtractionResult({
    required this.path,
    required this.type,
    required this.plainText,
    this.title,
  });

  final String path;
  final SupportedDocumentType type;
  final String plainText;
  final String? title;

  List<String> get paragraphs => plainText
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
}

class DocumentTextExtractor {
  Future<DocumentExtractionResult> extractFromFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('File not found: $filePath');
    }
    final bytes = await file.readAsBytes();
    final type = documentTypeFromPath(filePath);
    switch (type) {
      case SupportedDocumentType.pdf:
        return _extractPdf(filePath, bytes);
      case SupportedDocumentType.docx:
        return _extractDocx(filePath, bytes);
      case SupportedDocumentType.epub:
        return _extractEpub(filePath, bytes);
      case SupportedDocumentType.unknown:
        throw UnsupportedError(
          'Unsupported document type: ${p.extension(filePath)}',
        );
    }
  }

  DocumentExtractionResult _extractPdf(String filePath, List<int> bytes) {
    final document = pdf.PdfDocument(inputBytes: bytes);
    try {
      if (document.pages.count == 0) {
        return DocumentExtractionResult(
          path: filePath,
          type: SupportedDocumentType.pdf,
          plainText: '',
          title: p.basenameWithoutExtension(filePath),
        );
      }
      final extractor = pdf.PdfTextExtractor(document);
      final raw = extractor.extractText(
        startPageIndex: 0,
        endPageIndex: document.pages.count - 1,
      );
      return DocumentExtractionResult(
        path: filePath,
        type: SupportedDocumentType.pdf,
        plainText: _normalizePdfText(raw),
        title: p.basenameWithoutExtension(filePath),
      );
    } finally {
      document.dispose();
    }
  }

  DocumentExtractionResult _extractDocx(String filePath, List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final xmlBytes = _readArchiveEntryBytes(archive, 'word/document.xml');
    if (xmlBytes == null || xmlBytes.isEmpty) {
      throw const FormatException('Invalid DOCX: missing word/document.xml');
    }

    final xmlText = utf8.decode(xmlBytes, allowMalformed: true);
    final document = XmlDocument.parse(xmlText);
    final paragraphs = <String>[];

    for (final node in document.descendants.whereType<XmlElement>()) {
      if (node.name.local != 'p') continue;
      final paragraph = _extractDocxParagraph(node);
      if (paragraph.isNotEmpty) {
        paragraphs.add(paragraph);
      }
    }

    final title =
        _readDocxCoreTitle(archive) ?? p.basenameWithoutExtension(filePath);
    return DocumentExtractionResult(
      path: filePath,
      type: SupportedDocumentType.docx,
      plainText: _normalizeBlockText(paragraphs.join('\n\n')),
      title: title,
    );
  }

  DocumentExtractionResult _extractEpub(String filePath, List<int> bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final opfPath = _resolveEpubOpfPath(archive);
    if (opfPath == null) {
      throw const FormatException('Invalid EPUB: missing OPF package file');
    }

    final opfBytes = _readArchiveEntryBytes(archive, opfPath);
    if (opfBytes == null || opfBytes.isEmpty) {
      throw const FormatException('Invalid EPUB: cannot read OPF package file');
    }

    final opfText = utf8.decode(opfBytes, allowMalformed: true);
    final opf = XmlDocument.parse(opfText);
    final opfDir = p.dirname(opfPath);

    final manifest = <String, String>{};
    for (final item in opf.descendants.whereType<XmlElement>()) {
      if (item.name.local != 'item') continue;
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null || id.isEmpty || href.isEmpty) continue;
      manifest[id] = p.normalize(p.join(opfDir, href));
    }

    final spineRefs = <String>[];
    for (final itemref in opf.descendants.whereType<XmlElement>()) {
      if (itemref.name.local != 'itemref') continue;
      final idref = itemref.getAttribute('idref');
      if (idref != null && idref.isNotEmpty) {
        spineRefs.add(idref);
      }
    }

    final chapterPaths = <String>[];
    if (spineRefs.isNotEmpty) {
      for (final idref in spineRefs) {
        final chapterPath = manifest[idref];
        if (chapterPath != null) {
          chapterPaths.add(chapterPath);
        }
      }
    } else {
      for (final file in archive.files) {
        final lower = file.name.toLowerCase();
        if (lower.endsWith('.xhtml') ||
            lower.endsWith('.html') ||
            lower.endsWith('.htm')) {
          chapterPaths.add(p.normalize(file.name));
        }
      }
      chapterPaths.sort();
    }

    final chapterTexts = <String>[];
    for (final chapterPath in chapterPaths) {
      final chapterBytes = _readArchiveEntryBytes(archive, chapterPath);
      if (chapterBytes == null || chapterBytes.isEmpty) continue;
      final chapterHtml = utf8.decode(chapterBytes, allowMalformed: true);
      final text = _extractHtmlText(chapterHtml);
      if (text.isNotEmpty) {
        chapterTexts.add(text);
      }
    }

    final title = _readEpubTitle(opf) ?? p.basenameWithoutExtension(filePath);
    return DocumentExtractionResult(
      path: filePath,
      type: SupportedDocumentType.epub,
      plainText: _normalizeBlockText(chapterTexts.join('\n\n')),
      title: title,
    );
  }

  String _extractDocxParagraph(XmlElement paragraph) {
    final buffer = StringBuffer();
    for (final node in paragraph.descendants.whereType<XmlNode>()) {
      if (node is! XmlElement) continue;
      switch (node.name.local) {
        case 't':
          buffer.write(node.innerText);
          break;
        case 'tab':
          buffer.write(' ');
          break;
        case 'br':
          buffer.write('\n');
          break;
      }
    }
    return _normalizeInlineText(buffer.toString());
  }

  String _extractHtmlText(String html) {
    final document = html_parser.parse(html);
    final nodes = document.querySelectorAll(
      'h1, h2, h3, h4, h5, h6, p, li, blockquote, pre',
    );
    if (nodes.isNotEmpty) {
      final blocks = nodes
          .map((node) => _normalizeInlineText(node.text))
          .where((text) => text.isNotEmpty)
          .toList();
      if (blocks.isNotEmpty) {
        return blocks.join('\n\n');
      }
    }
    return _normalizeInlineText(
      document.body?.text ?? document.documentElement?.text ?? '',
    );
  }

  String? _resolveEpubOpfPath(Archive archive) {
    final containerBytes = _readArchiveEntryBytes(
      archive,
      'META-INF/container.xml',
    );
    if (containerBytes != null && containerBytes.isNotEmpty) {
      final containerText = utf8.decode(containerBytes, allowMalformed: true);
      final containerXml = XmlDocument.parse(containerText);
      for (final rootFile in containerXml.descendants.whereType<XmlElement>()) {
        if (rootFile.name.local != 'rootfile') continue;
        final fullPath = rootFile.getAttribute('full-path');
        if (fullPath != null && fullPath.trim().isNotEmpty) {
          return p.normalize(fullPath.trim());
        }
      }
    }

    for (final file in archive.files) {
      if (file.name.toLowerCase().endsWith('.opf')) {
        return p.normalize(file.name);
      }
    }
    return null;
  }

  String? _readDocxCoreTitle(Archive archive) {
    final coreBytes = _readArchiveEntryBytes(archive, 'docProps/core.xml');
    if (coreBytes == null || coreBytes.isEmpty) return null;
    final coreText = utf8.decode(coreBytes, allowMalformed: true);
    final coreXml = XmlDocument.parse(coreText);
    for (final node in coreXml.descendants.whereType<XmlElement>()) {
      if (node.name.local == 'title') {
        final text = node.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  String? _readEpubTitle(XmlDocument opf) {
    for (final node in opf.descendants.whereType<XmlElement>()) {
      if (node.name.local == 'title') {
        final text = node.innerText.trim();
        if (text.isNotEmpty) return text;
      }
    }
    return null;
  }

  List<int>? _readArchiveEntryBytes(Archive archive, String entryPath) {
    final normalized = p
        .normalize(entryPath)
        .replaceAll('\\', '/')
        .toLowerCase();
    for (final file in archive.files) {
      final filePath = p
          .normalize(file.name)
          .replaceAll('\\', '/')
          .toLowerCase();
      if (filePath == normalized) {
        return file.readBytes();
      }
    }
    return null;
  }

  String _normalizePdfText(String text) {
    var normalized = text.replaceAll('\u00A0', ' ').replaceAll('\r', '\n');
    normalized = normalized.replaceAll(RegExp(r'(?<!\n)\n(?!\n)'), ' ');
    normalized = normalized.replaceAllMapped(
      RegExp(r'([.!?;:,])(?=[A-Za-z])'),
      (m) => '${m.group(1)} ',
    );
    normalized = normalized.replaceAll(RegExp(r'(?<=[a-z])(?=[A-Z])'), ' ');
    normalized = normalized.replaceAll(RegExp(r'[ \t]+'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return normalized.trim();
  }

  String _normalizeBlockText(String text) {
    var normalized = text.replaceAll('\u00A0', ' ').replaceAll('\r', '\n');
    normalized = normalized.replaceAll(RegExp(r'[ \t]+'), ' ');
    normalized = normalized.replaceAll(RegExp(r' *\n *'), '\n');
    normalized = normalized.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return normalized.trim();
  }

  String _normalizeInlineText(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

final documentTextExtractorProvider = Provider<DocumentTextExtractor>((ref) {
  return DocumentTextExtractor();
});
