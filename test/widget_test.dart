import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'help_tour_seen': true});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(FleetFlowApp(prefs: prefs));
    expect(find.text('FleetFlow'), findsOneWidget);
  });

  testWidgets('Own vessel settings accept typed boat profile details', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'help_tour_seen': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(FleetFlowApp(prefs: prefs));
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Boat name'),
      'Pegasus',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Sail number / Call sign'),
      'usa 1234',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Boat class'),
      'J/111',
    );
    await tester.pumpAndSettle();

    expect(find.text('Pegasus'), findsWidgets);
    expect(find.text('J/111 · USA 1234'), findsWidgets);
  });

  testWidgets('Settings includes a feedback email action', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({'help_tour_seen': true});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(FleetFlowApp(prefs: prefs));
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Send Feedback'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Send Feedback'), findsOneWidget);
    expect(find.text('Email feedback to the FleetFlow team'), findsOneWidget);
  });
}
