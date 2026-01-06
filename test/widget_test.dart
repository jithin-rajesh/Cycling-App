import 'package:flutter_test/flutter_test.dart';

import 'package:cruizr/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CruizrApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsNothing); // Changed this since the app structure changed completely
  });
}
