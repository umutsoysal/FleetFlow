import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart' hide ConnectionState;
import '../models/fleet_manager.dart' as fm;
import '../models/theme_provider.dart';
import 'legal_document_screen.dart';

const _appVersionLabel = '1.0.0 (2)';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _mmsiController;
  late TextEditingController _coverageController;

  @override
  void initState() {
    super.initState();
    final fleet = context.read<FleetManager>();
    _hostController = TextEditingController(text: fleet.host);
    _portController = TextEditingController(text: fleet.port.toString());
    _mmsiController = TextEditingController(text: fleet.ownMmsi?.toString() ?? '');
    _coverageController = TextEditingController(
      text: fleet.coverageRadiusNm.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _mmsiController.dispose();
    _coverageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'Connection',
            description: 'Connect to a B&G Zeus3, Cortex, or simulator harness over TCP.',
            child: Column(
              children: [
                TextField(
                  controller: _hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host / IP Address',
                    hintText: '192.168.1.1',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wifi),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    hintText: '10110',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.numbers),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: fleet.connectionState == fm.ConnectionState.connected
                            ? fleet.disconnect
                            : null,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: fleet.connectionState != fm.ConnectionState.connected
                            ? () {
                                fleet.host = _hostController.text.trim();
                                fleet.port = int.tryParse(_portController.text) ?? 10110;
                                fleet.ownMmsi = int.tryParse(_mmsiController.text.trim());
                                fleet.connect();
                              }
                            : null,
                        icon: const Icon(Icons.link),
                        label: const Text('Connect'),
                      ),
                    ),
                  ],
                ),
                if (fleet.connectionState == fm.ConnectionState.error) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      fleet.errorMessage,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                _SettingsInfoRow('Status', fleet.connectionState.label),
                _SettingsInfoRow('Messages', fleet.messageCount.toString()),
                _SettingsInfoRow(
                  'Last message',
                  fleet.lastMessageTime != null
                      ? '${DateTime.now().difference(fleet.lastMessageTime!).inSeconds}s ago'
                      : '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Own Vessel',
            description: 'Choose how your own boat is positioned and how far the coverage ring extends.',
            child: Column(
              children: [
                TextField(
                  controller: _mmsiController,
                  decoration: const InputDecoration(
                    labelText: 'Own MMSI (optional)',
                    hintText: '338123456',
                    helperText: 'Use AIS when your own vessel is in the stream.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_boat),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _coverageController,
                  decoration: const InputDecoration(
                    labelText: 'Coverage Circle Radius',
                    hintText: '20',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.radar),
                    suffixText: 'nm',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (value) {
                    final parsed = double.tryParse(value.trim());
                    if (parsed != null && parsed > 0) {
                      context.read<FleetManager>().coverageRadiusNm = parsed;
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.my_location, size: 20),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Own boat source',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: false,
                          label: Text('AIS'),
                          icon: Icon(Icons.settings_input_antenna, size: 16),
                        ),
                        ButtonSegment(
                          value: true,
                          label: Text('GPS'),
                          icon: Icon(Icons.gps_fixed, size: 16),
                        ),
                      ],
                      selected: {fleet.useGpsForOwnBoat},
                      onSelectionChanged: (selection) {
                        fleet.useGpsForOwnBoat = selection.first;
                      },
                      style: const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _SettingsInfoRow('Active source', fleet.ownPositionSource),
                _SettingsInfoRow(
                  'GPS backup',
                  fleet.gpsPosition != null
                      ? '${fleet.gpsPosition!.latitude.toStringAsFixed(5)}, '
                          '${fleet.gpsPosition!.longitude.toStringAsFixed(5)}'
                      : 'Unavailable',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'Appearance',
            description: 'Switch between day, night, and red night layouts from one place.',
            child: SegmentedButton<AppThemeMode>(
              segments: AppThemeMode.values
                  .map(
                    (mode) => ButtonSegment<AppThemeMode>(
                      value: mode,
                      label: Text(mode.label),
                      icon: Icon(mode.icon, size: 16),
                    ),
                  )
                  .toList(),
              selected: {themeProvider.mode},
              onSelectionChanged: (selection) {
                themeProvider.mode = selection.first;
              },
              multiSelectionEnabled: false,
            ),
          ),
          const SizedBox(height: 16),
          _SettingsSection(
            title: 'App',
            description: 'The standard app details crews expect before a release.',
            child: Column(
              children: [
                _SettingsActionTile(
                  icon: Icons.info_outline,
                  title: 'About FleetFlow',
                  subtitle: 'Purpose, safety notice, and release details',
                  onTap: () => _openDocument(
                    context,
                    title: 'About FleetFlow',
                    summary:
                        'FleetFlow is a live race-day fleet viewer built for offshore sailing teams. '
                        'It focuses on fast situational awareness from AIS, NMEA, and device GPS.',
                    sections: const [
                      DocumentSection(
                        heading: 'What it does',
                        body:
                            'FleetFlow connects to a chartplotter or simulator harness over TCP, '
                            'parses incoming AIS and NMEA traffic, and renders the fleet on a live map with speed and course details.',
                      ),
                      DocumentSection(
                        heading: 'Designed for race day',
                        body:
                            'Day, night, and red night themes are included so the same device can stay readable from bright daylight through overnight legs.',
                      ),
                      DocumentSection(
                        heading: 'Safety notice',
                        body:
                            'FleetFlow supports situational awareness only. It is not a substitute for official navigation equipment, charts, watchstanding, or seamanship.',
                      ),
                      DocumentSection(
                        heading: 'Release',
                        body: 'Current app version: $_appVersionLabel.',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _SettingsActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  subtitle: 'How connection data, AIS data, and GPS data are handled',
                  onTap: () => _openDocument(
                    context,
                    title: 'Privacy Policy',
                    summary:
                        'FleetFlow is designed to keep operational data on the device whenever possible.',
                    sections: const [
                      DocumentSection(
                        heading: 'Data stored on device',
                        body:
                            'FleetFlow stores connection settings, own-vessel preferences, selected fleet boats, and theme choices locally on the device so they persist between launches.',
                      ),
                      DocumentSection(
                        heading: 'Live race data',
                        body:
                            'AIS, NMEA, and GPS information is used to power the app experience in real time. The current app does not include account creation, cloud sync, or in-app advertising.',
                      ),
                      DocumentSection(
                        heading: 'Location data',
                        body:
                            'If GPS is enabled for the own-boat marker, location is used to render your vessel on the map and to provide a fallback when AIS is unavailable.',
                      ),
                      DocumentSection(
                        heading: 'Third-party services',
                        body:
                            'When online charts are enabled, map tiles may be requested from a third-party map provider. Those requests can expose standard network metadata such as IP address.',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _SettingsActionTile(
                  icon: Icons.description_outlined,
                  title: 'Terms of Use',
                  subtitle: 'Usage expectations, limitations, and operator responsibility',
                  onTap: () => _openDocument(
                    context,
                    title: 'Terms of Use',
                    summary:
                        'By using FleetFlow, operators agree to use the app as a supplemental aid and remain responsible for navigation and safety decisions.',
                    sections: const [
                      DocumentSection(
                        heading: 'Supplemental use only',
                        body:
                            'FleetFlow should be treated as a companion display. It must not be the sole source of navigation, collision avoidance, or emergency decision-making.',
                      ),
                      DocumentSection(
                        heading: 'Data quality',
                        body:
                            'Incoming feeds can be delayed, incomplete, malformed, or unavailable. The operator is responsible for validating critical information against primary instruments and official sources.',
                      ),
                      DocumentSection(
                        heading: 'Operator responsibility',
                        body:
                            'The skipper and crew remain fully responsible for compliance with race rules, local regulations, and safe vessel operation at all times.',
                      ),
                      DocumentSection(
                        heading: 'Availability',
                        body:
                            'App behavior depends on device performance, network quality, connected hardware, and external data services. Continuous service is not guaranteed.',
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                _SettingsActionTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Open Source Licenses',
                  subtitle: 'Review package licenses used by the app',
                  onTap: () {
                    showLicensePage(
                      context: context,
                      applicationName: 'FleetFlow',
                      applicationVersion: _appVersionLabel,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openDocument(
    BuildContext context, {
    required String title,
    required String summary,
    required List<DocumentSection> sections,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(
          title: title,
          summary: summary,
          sections: sections,
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _SettingsSection({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingsInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _SettingsInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
