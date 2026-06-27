import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(FleetFlowApp(prefs: prefs));
    expect(find.text('FleetFlow'), findsOneWidget);
  });
}
