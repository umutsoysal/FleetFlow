import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/fleet_manager.dart';
import 'models/theme_provider.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(FleetFlowApp(prefs: prefs));
}

class FleetFlowApp extends StatelessWidget {
  final SharedPreferences prefs;
  const FleetFlowApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FleetManager(prefs: prefs)),
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs: prefs)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'FleetFlow',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.theme,
          home: const DashboardScreen(),
        ),
      ),
    );
  }
}
