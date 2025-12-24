import 'package:flutter_test/flutter_test.dart';
import 'package:video2ascii_flutter/main.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const Video2AsciiApp());

    // Verify that the app loads with the title
    expect(find.text('VIDEO2ASCII'), findsOneWidget);
  });
}
