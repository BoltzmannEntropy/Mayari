class AudiobookChunking {
  static const int defaultTargetChunkChars = 180;
  static const int defaultMaxChunks = 1200;

  static List<String> prepareChunksForGeneration(
    List<String> chunks, {
    int targetChunkChars = defaultTargetChunkChars,
    int maxChunks = defaultMaxChunks,
  }) {
    final prepared = <String>[];

    for (final raw in chunks) {
      final normalized = raw
          .replaceAll('\u00A0', ' ')
          .replaceAll('\r', '\n')
          .replaceAll(RegExp(r'[ \t]+'), ' ')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      if (normalized.isEmpty) continue;

      final sentences = normalized
          .split(RegExp(r'(?<=[.!?])\s+|\n+'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (sentences.isEmpty) {
        _splitLongChunk(normalized, targetChunkChars, prepared);
        continue;
      }

      final current = StringBuffer();
      for (final sentence in sentences) {
        final candidate = current.isEmpty
            ? sentence
            : '${current.toString()} $sentence';
        if (candidate.length <= targetChunkChars) {
          current
            ..clear()
            ..write(candidate);
          continue;
        }

        if (current.isNotEmpty) {
          prepared.add(current.toString().trim());
          current.clear();
        }

        if (sentence.length <= targetChunkChars) {
          current.write(sentence);
        } else {
          _splitLongChunk(sentence, targetChunkChars, prepared);
        }
      }

      if (current.isNotEmpty) {
        prepared.add(current.toString().trim());
      }
    }

    final cleaned = <String>[];
    for (final chunk in prepared) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) continue;
      cleaned.add(trimmed);
      if (cleaned.length >= maxChunks) break;
    }

    return cleaned;
  }

  static List<String> prepareTextForGeneration(
    String text, {
    int targetChunkChars = defaultTargetChunkChars,
    int maxChunks = defaultMaxChunks,
  }) {
    final paragraphs = text
        .split(RegExp(r'\n\s*\n'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    return prepareChunksForGeneration(
      paragraphs,
      targetChunkChars: targetChunkChars,
      maxChunks: maxChunks,
    );
  }

  static void _splitLongChunk(
    String chunk,
    int targetChunkChars,
    List<String> out,
  ) {
    final words = chunk
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return;

    final current = StringBuffer();
    for (final word in words) {
      final candidate = current.isEmpty ? word : '${current.toString()} $word';
      if (candidate.length <= targetChunkChars) {
        current
          ..clear()
          ..write(candidate);
        continue;
      }
      if (current.isNotEmpty) {
        out.add(current.toString().trim());
        current.clear();
      }
      if (word.length > targetChunkChars) {
        var start = 0;
        while (start < word.length) {
          final end = (start + targetChunkChars).clamp(0, word.length).toInt();
          out.add(word.substring(start, end).trim());
          start = end;
        }
      } else {
        current.write(word);
      }
    }
    if (current.isNotEmpty) {
      out.add(current.toString().trim());
    }
  }
}
