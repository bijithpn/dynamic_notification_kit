import 'package:dynamic_notification_kit_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shell shows three tabs', (tester) async {
    await tester.pumpWidget(const ShowcaseApp());
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Minimal'), findsOneWidget);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Delivery tracking'), findsOneWidget);
  });
}
