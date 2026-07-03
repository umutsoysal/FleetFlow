import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fleet_manager.dart';
import '../models/theme_provider.dart';
import '../onboarding/help_tour.dart';
import '../widgets/fleet_summary_bar.dart';
import '../widgets/fleet_table.dart';
import '../widgets/fleet_map.dart';
import '../widgets/connection_indicator.dart';
import '../widgets/scan_button.dart';
import 'app_settings_screen.dart';
import 'fleet_management_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _keyTourSeen = 'help_tour_seen';

  final _connectionKey = GlobalKey();
  final _summaryKey = GlobalKey();
  final _mapKey = GlobalKey();
  final _tableKey = GlobalKey();
  final _themeKey = GlobalKey();
  final _filterKey = GlobalKey();
  final _fleetManagerKey = GlobalKey();
  final _settingsKey = GlobalKey();
  final _scanButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _maybeShowFirstRunTour(),
    );
  }

  Future<void> _maybeShowFirstRunTour() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_keyTourSeen) ?? false) return;
    if (!mounted) return;
    _startTour();
  }

  void _startTour() {
    HelpTour.start(
      context,
      steps: [
        HelpTourStep(
          targetKey: _scanButtonKey,
          icon: Icons.radar,
          title: 'Start scanning',
          body:
              'FleetFlow never connects on its own — that would burn '
              'through data. Tap Start when you want live AIS traffic, '
              'and tap again to pause. Your fleet stays on screen while '
              'paused.',
        ),
        HelpTourStep(
          targetKey: _connectionKey,
          icon: Icons.wifi,
          title: 'Connection status',
          body:
              'Watch this dot: green means live NMEA data is flowing from '
              'your Zeus3, Cortex, or simulator. Grey means you are not '
              'connected yet.',
        ),
        HelpTourStep(
          targetKey: _summaryKey,
          icon: Icons.insights,
          title: 'Fleet at a glance',
          body:
              'Live totals for the boats being tracked, the fleet average '
              'and top speed, and how many AIS messages have arrived.',
        ),
        HelpTourStep(
          targetKey: _mapKey,
          icon: Icons.map,
          title: 'Live race map',
          body:
              'Boats in range are drawn with their heading and recent '
              'track. Your own vessel and coverage ring appear once you are '
              'connected.',
        ),
        HelpTourStep(
          targetKey: _tableKey,
          icon: Icons.sailing,
          title: 'Fleet list',
          body:
              'The same fleet as cards with speed trends. Boats that stop '
              'reporting are dimmed as stale.',
        ),
        HelpTourStep(
          targetKey: _themeKey,
          icon: Icons.dark_mode,
          title: 'Day, night, red night',
          body:
              'Tap to cycle themes and stay readable from a bright cockpit '
              'to an overnight watch without losing night vision.',
        ),
        HelpTourStep(
          targetKey: _filterKey,
          icon: Icons.filter_alt,
          title: 'Fleet filter',
          body:
              'Toggle between every AIS target in range and just the boats '
              'in your fleet.',
        ),
        HelpTourStep(
          targetKey: _fleetManagerKey,
          icon: Icons.groups,
          title: 'Your fleet',
          body:
              'Pick which boats count as your fleet — the competitors you '
              'want to follow through the race.',
        ),
        HelpTourStep(
          targetKey: _settingsKey,
          icon: Icons.settings,
          title: 'Connect your instruments',
          body:
              'Enter your chartplotter\'s IP and port in Settings, then use '
              'the Start button below to begin scanning. You can replay '
              'this tour from Settings anytime.',
        ),
      ],
      onFinished: _markTourSeen,
    );
  }

  Future<void> _markTourSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTourSeen, true);
  }

  Future<void> _openSettings(FleetManager fleet) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: fleet,
          child: const AppSettingsScreen(),
        ),
      ),
    );
    if (result == AppSettingsScreen.replayTourResult && mounted) {
      // Let the settings route finish animating out before spotlighting.
      await Future.delayed(const Duration(milliseconds: 350));
      if (mounted) _startTour();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();
    final isWide = MediaQuery.of(context).size.width > 700;

    return Scaffold(
      appBar: AppBar(
        title: const Text('FleetFlow'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: KeyedSubtree(
            key: _connectionKey,
            child: const ConnectionIndicator(),
          ),
        ),
        leadingWidth: 120,
        actions: [
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => IconButton(
              key: _themeKey,
              icon: Icon(themeProvider.mode.icon),
              tooltip: '${themeProvider.mode.label} mode — tap to switch',
              onPressed: themeProvider.cycle,
            ),
          ),
          IconButton(
            key: _filterKey,
            icon: Icon(
              fleet.fleetOnly ? Icons.filter_alt : Icons.filter_alt_outlined,
              color: fleet.fleetOnly
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: fleet.fleetOnly
                ? 'Showing fleet only'
                : 'Showing all boats',
            onPressed: () => fleet.fleetOnly = !fleet.fleetOnly,
          ),
          IconButton(
            key: _fleetManagerKey,
            icon: Badge(
              isLabelVisible: fleet.fleetMmsis.isNotEmpty,
              label: Text('${fleet.fleetMmsis.length}'),
              child: const Icon(Icons.groups),
            ),
            tooltip: 'Fleet manager',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: fleet,
                    child: const FleetManagementScreen(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            key: _settingsKey,
            icon: const Icon(Icons.settings),
            onPressed: () => _openSettings(fleet),
          ),
        ],
      ),
      body: Column(
        children: [
          KeyedSubtree(key: _summaryKey, child: const FleetSummaryBar()),
          Expanded(
            child: isWide
                ? Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: KeyedSubtree(
                          key: _mapKey,
                          child: const FleetMap(),
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        flex: 1,
                        child: KeyedSubtree(
                          key: _tableKey,
                          child: FleetTable(),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: KeyedSubtree(
                          key: _mapKey,
                          child: const FleetMap(),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        flex: 1,
                        child: KeyedSubtree(
                          key: _tableKey,
                          child: FleetTable(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: KeyedSubtree(
        key: _scanButtonKey,
        child: const ScanButtonBar(),
      ),
    );
  }
}
