import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mayari/services/audiobook_chunking.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'prepareTextForGeneration chunks long history excerpt for audiobook use',
    () {
      final source = File(
        p.join(
          Directory.current.path,
          'assets',
          'examples',
          'texts',
          'public_domain_history_wells_excerpt.txt',
        ),
      );
      expect(source.existsSync(), isTrue);

      final text = source.readAsStringSync();
      final chunks = AudiobookChunking.prepareTextForGeneration(text);

      expect(chunks.length, greaterThan(200));
      expect(chunks.length, lessThanOrEqualTo(1200));
      expect(chunks.any((chunk) => chunk.length > 180), isFalse);
      expect(chunks.any((chunk) => chunk.trim().isEmpty), isFalse);
    },
  );

  test(
    'prepareChunksForGeneration preserves repeated text to avoid data loss',
    () {
      const repeated = [
        'Hello world. This is a repeated sentence.',
        'Hello world. This is a repeated sentence.',
        'A different sentence follows.',
        'A different sentence follows.',
      ];

      final chunks = AudiobookChunking.prepareChunksForGeneration(repeated);

      expect(chunks, hasLength(4));
      expect(chunks[0], contains('Hello world'));
      expect(chunks[1], contains('Hello world'));
      expect(chunks[2], contains('different sentence'));
      expect(chunks[3], contains('different sentence'));
    },
  );

  test('prepareChunksForGeneration splits very long single words safely', () {
    final longWord = 'x' * 700;
    final chunks = AudiobookChunking.prepareChunksForGeneration([longWord]);

    expect(chunks, isNotEmpty);
    expect(chunks.any((chunk) => chunk.length > 180), isFalse);
    expect(chunks.join(), longWord);
  });
}
