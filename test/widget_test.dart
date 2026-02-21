import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mayari/main.dart';
import 'package:mayari/providers/tts_provider.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServerStatusProvider.overrideWith((ref) => Stream.value(true)),
          ttsStatusProvider.overrideWith(
            (ref) => Stream.value('Backend connected'),
          ),
        ],
        child: const MayariApp(),
      ),
    );
    expect(find.text('Mayari'), findsOneWidget);
  });
}
