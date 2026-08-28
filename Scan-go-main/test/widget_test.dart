import 'package:flutter_test/flutter_test.dart';
import 'package:scango/main.dart';

void main() {
  testWidgets('ScanGoApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ScanGoApp());
    expect(find.text('Start Shopping'), findsOneWidget);
  });
}
