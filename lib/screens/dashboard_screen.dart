import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart';
import '../widgets/fleet_summary_bar.dart';
import '../widgets/fleet_table.dart';
import '../widgets/fleet_map.dart';
import '../widgets/connection_indicator.dart';
import 'connection_settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.read<FleetManager>();
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FleetFlow'),
        leading: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: ConnectionIndicator(),
        ),
        leadingWidth: 160,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => ChangeNotifierProvider.value(
                  value: fleet,
                  child: const ConnectionSettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const FleetSummaryBar(),
          Expanded(
            child: isWide
                ? Row(
                    children: [
                      const Expanded(flex: 2, child: FleetMap()),
                      const VerticalDivider(width: 1),
                      Expanded(flex: 1, child: FleetTable()),
                    ],
                  )
                : Column(
                    children: [
                      const Expanded(flex: 1, child: FleetMap()),
                      const Divider(height: 1),
                      Expanded(flex: 1, child: FleetTable()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
