import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mayari/main.dart';
import 'package:mayari/providers/tts_provider.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ttsServerStatusProvider.overrideWith((ref) => Stream.value(true)),
          backendStatusProvider.overrideWith(
            (ref) => Stream.value('Backend connected'),
          ),
        ],
        child: const MayariApp(),
      ),
    );
    expect(find.text('Mayari'), findsOneWidget);
  });
}
