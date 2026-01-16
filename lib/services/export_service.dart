import '../models/source.dart';

class ExportService {
  String exportToMarkdown(List<Source> sources) {
    final buffer = StringBuffer();
    buffer.writeln('# Collected Quotes');
    buffer.writeln();

    for (final source in sources) {
      if (source.quotes.isEmpty) continue;

      buffer.writeln('## ${source.citation}');
      buffer.writeln();

      final sortedQuotes = List.of(source.quotes)
        ..sort((a, b) => a.order.compareTo(b.order));

      for (final quote in sortedQuotes) {
        buffer.writeln('> "${quote.text}"');
        buffer.writeln('>');
        buffer.writeln('> — p. ${quote.pageNumber}');
        if (quote.notes != null && quote.notes!.isNotEmpty) {
          buffer.writeln('>');
          buffer.writeln('> *Note: ${quote.notes}*');
        }
        buffer.writeln();
      }
    }

    return buffer.toString();
  }
}
