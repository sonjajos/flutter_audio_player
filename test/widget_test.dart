import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_audio_player/main.dart';

void main() {
  testWidgets('App renders without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AudioPlayerApp()));
    expect(find.text('Audio Player'), findsOneWidget);
  });
}
