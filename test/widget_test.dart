import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const FleetFlowApp());
    expect(find.text('FleetFlow'), findsOneWidget);
  });
}
