import 'package:path/path.dart' as p;

enum SupportedDocumentType { pdf, docx, epub, unknown }

const Set<String> supportedDocumentExtensions = {'.pdf', '.docx', '.epub'};

SupportedDocumentType documentTypeFromPath(String filePath) {
  final ext = p.extension(filePath).toLowerCase();
  switch (ext) {
    case '.pdf':
      return SupportedDocumentType.pdf;
    case '.docx':
      return SupportedDocumentType.docx;
    case '.epub':
      return SupportedDocumentType.epub;
    default:
      return SupportedDocumentType.unknown;
  }
}

bool isSupportedDocumentPath(String filePath) =>
    supportedDocumentExtensions.contains(p.extension(filePath).toLowerCase());
