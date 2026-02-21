import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:mayari/services/examples_loader_service.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._supportPath);

  final String _supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => _supportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads bundled example documents and audiobooks', () async {
    final original = PathProviderPlatform.instance;
    final tempDir = await Directory.systemTemp.createTemp(
      'mayari_examples_test_',
    );

    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
    addTearDown(() async {
      PathProviderPlatform.instance = original;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final bundle = await ExamplesLoaderService().loadExamples();

    expect(bundle.documents.length, 3);
    expect(bundle.audiobooks.length, 3);
    expect(Directory(bundle.documentsDirectory).existsSync(), isTrue);

    for (final doc in bundle.documents) {
      expect(File(doc.path).existsSync(), isTrue);
      final ext = p.extension(doc.path).toLowerCase();
      expect({'.pdf', '.docx', '.epub'}.contains(ext), isTrue);
    }

    for (final audio in bundle.audiobooks) {
      expect(File(audio.path).existsSync(), isTrue);
      expect(p.extension(audio.path).toLowerCase(), '.wav');
      expect(audio.durationSeconds, greaterThan(10));
    }
  });
}
