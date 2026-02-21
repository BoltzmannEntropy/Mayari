import 'package:flutter_test/flutter_test.dart';
import 'package:mayari/services/tts_service.dart';

void main() {
  test('default voice catalog includes all supported language codes', () {
    final languageCodes = defaultVoices.map((v) => v.languageCode).toSet();
    expect(
      languageCodes,
      containsAll(<String>{
        'en-us',
        'en-gb',
        'es-es',
        'fr-fr',
        'hi-in',
        'it-it',
        'ja-jp',
        'pt-br',
        'zh-cn',
      }),
    );
  });

  test('default voice catalog includes multilingual representative voices', () {
    final ids = defaultVoices.map((v) => v.id).toSet();
    expect(
      ids,
      containsAll(<String>{
        'af_heart',
        'bm_george',
        'ef_dora',
        'ff_siwis',
        'hf_alpha',
        'im_nicola',
        'jf_tebukuro',
        'pm_alex',
        'zm_yunyang',
      }),
    );
  });

  test('default voice catalog includes all requested Kokoro voices', () {
    final ids = defaultVoices.map((v) => v.id).toSet();
    expect(ids.length, greaterThanOrEqualTo(54));
    expect(
      ids,
      containsAll(<String>{
        'af_alloy',
        'af_aoede',
        'af_bella',
        'af_heart',
        'af_jessica',
        'af_kore',
        'af_nicole',
        'af_nova',
        'af_river',
        'af_sarah',
        'af_sky',
        'am_adam',
        'am_echo',
        'am_eric',
        'am_fenrir',
        'am_liam',
        'am_michael',
        'am_onyx',
        'am_puck',
        'am_santa',
        'bf_alice',
        'bf_emma',
        'bf_isabella',
        'bf_lily',
        'bm_daniel',
        'bm_fable',
        'bm_george',
        'bm_lewis',
        'ef_dora',
        'em_alex',
        'em_santa',
        'ff_siwis',
        'hf_alpha',
        'hf_beta',
        'hm_omega',
        'hm_psi',
        'if_sara',
        'im_nicola',
        'jf_alpha',
        'jf_gongitsune',
        'jf_nezumi',
        'jf_tebukuro',
        'jm_kumo',
        'pf_dora',
        'pm_alex',
        'pm_santa',
        'zf_xiaobei',
        'zf_xiaoni',
        'zf_xiaoxiao',
        'zf_xiaoyi',
        'zm_yunjian',
        'zm_yunxi',
        'zm_yunxia',
        'zm_yunyang',
      }),
    );
  });
}
