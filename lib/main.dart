import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/fleet_manager.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const FleetFlowApp());
}

class FleetFlowApp extends StatelessWidget {
  const FleetFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FleetManager(),
      child: MaterialApp(
        title: 'FleetFlow',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D47A1),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const DashboardScreen(),
      ),
    );
  }
}
