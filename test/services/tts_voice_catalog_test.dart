import 'package:flutter_test/flutter_test.dart';
import 'package:mayari/services/tts_service.dart';

void main() {
  test('default voice catalog includes US and UK languages', () {
    final languageCodes = defaultVoices.map((v) => v.languageCode).toSet();
    expect(languageCodes.contains('en-us'), isTrue);
    expect(languageCodes.contains('en-gb'), isTrue);
  });

  test('default voice catalog includes representative voices', () {
    final ids = defaultVoices.map((v) => v.id).toSet();
    expect(ids.contains('af_heart'), isTrue);
    expect(ids.contains('am_liam'), isTrue);
    expect(ids.contains('bf_emma'), isTrue);
    expect(ids.contains('bm_george'), isTrue);
  });
}
