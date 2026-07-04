import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart' hide ConnectionState;
import '../models/fleet_manager.dart' as fm;
import '../models/theme_provider.dart';
import 'legal_document_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  /// Returned as the route result when the user asks to replay the help tour.
  static const replayTourResult = 'replay_help_tour';

  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _mmsiController;
  late TextEditingController _boatNameController;
  late TextEditingController _boatCallSignController;
  late TextEditingController _boatClassController;
  late TextEditingController _coverageController;
  String _appVersionLabel = '';

  @override
  void initState() {
    super.initState();
    final fleet = context.read<FleetManager>();
    _hostController = TextEditingController(text: fleet.host);
    _portController = TextEditingController(text: fleet.port.toString());
    _mmsiController = TextEditingController(
      text: fleet.ownMmsi?.toString() ?? '',
    );
    _boatNameController = TextEditingController(
      text: fleet.configuredOwnBoatName,
    );
    _boatCallSignController = TextEditingController(
      text: fleet.configuredOwnBoatCallSign,
    );
    _boatClassController = TextEditingController(
      text: fleet.configuredOwnBoatClass,
    );
    _coverageController = TextEditingController(
      text: fleet.coverageRadiusNm.toStringAsFixed(0),
    );
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() {
          _appVersionLabel = '${info.version} (${info.buildNumber})';
        });
      }
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _mmsiController.dispose();
    _boatNameController.dispose();
    _boatCallSignController.dispose();
    _boatClassController.dispose();
    _coverageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsSection(
            title: 'Connection',
            description:
                'Connect to a B&G Zeus3, Cortex, or simulator harness over TCP.',
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
                        onPressed:
                            fleet.connectionState ==
                                fm.ConnectionState.connected
                            ? fleet.disconnect
                            : null,
                        icon: const Icon(Icons.link_off),
                        label: const Text('Disconnect'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            fleet.connectionState !=
                                fm.ConnectionState.connected
                            ? () {
                                fleet.host = _hostController.text.trim();
                                fleet.port =
                                    int.tryParse(_portController.text) ?? 10110;
                                fleet.ownMmsi = int.tryParse(
                                  _mmsiController.text.trim(),
                                );
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
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
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
            description:
                'Set the identity, marker style, and source preferences for your boat.',
            child: Column(
              children: [
                TextField(
                  controller: _boatNameController,
                  decoration: const InputDecoration(
                    labelText: 'Boat name',
                    hintText: 'Pegasus',
                    helperText:
                        'Used for your own-boat marker and preview badge.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    context.read<FleetManager>().configuredOwnBoatName = value;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _boatCallSignController,
                  decoration: const InputDecoration(
                    labelText: 'Sail number / Call sign',
                    hintText: 'USA 1234',
                    helperText:
                        'Optional secondary identifier shown in boat configuration.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    context.read<FleetManager>().configuredOwnBoatCallSign =
                        value;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _boatClassController,
                  decoration: const InputDecoration(
                    labelText: 'Boat class',
                    hintText: 'J/111',
                    helperText:
                        'Optional class or model for a little more context.',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sailing_outlined),
                  ),
                  textCapitalization: TextCapitalization.words,
                  onChanged: (value) {
                    context.read<FleetManager>().configuredOwnBoatClass = value;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _mmsiController,
                  decoration: const InputDecoration(
                    labelText: 'Own MMSI (optional)',
                    hintText: '338123456',
                    helperText:
                        'Use AIS when your own vessel is in the stream.',
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) {
                    final parsed = double.tryParse(value.trim());
                    if (parsed != null && parsed > 0) {
                      context.read<FleetManager>().coverageRadiusNm = parsed;
                    }
                  },
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Own boat marker color',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _ownBoatColorOptions
                      .map(
                        (option) => _BoatColorChip(
                          option: option,
                          selected:
                              fleet.ownBoatColor.value == option.color.value,
                          onTap: () {
                            fleet.ownBoatColor = option.color;
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                _OwnBoatPreview(
                  name: fleet.ownBoatDisplayName,
                  profileLabel: fleet.ownBoatProfileLabel,
                  color: fleet.ownBoatColor,
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
                _SettingsInfoRow('Marker label', fleet.ownBoatDisplayName),
                _SettingsInfoRow(
                  'Boat profile',
                  fleet.ownBoatProfileLabel.isEmpty
                      ? 'Not set'
                      : fleet.ownBoatProfileLabel,
                ),
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
            description:
                'Switch between day, night, and red night layouts from one place.',
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
            description:
                'The standard app details crews expect before a release.',
            child: Column(
              children: [
                _SettingsActionTile(
                  icon: Icons.tour_outlined,
                  title: 'Replay Help Tour',
                  subtitle: 'Walk through the main dashboard features again',
                  onTap: () => Navigator.of(
                    context,
                  ).pop(AppSettingsScreen.replayTourResult),
                ),
                const Divider(height: 1),
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
                    sections: [
                      const DocumentSection(
                        heading: 'What it does',
                        body:
                            'FleetFlow connects to a chartplotter or simulator harness over TCP, '
                            'parses incoming AIS and NMEA traffic, and renders the fleet on a live map with speed and course details.',
                      ),
                      const DocumentSection(
                        heading: 'Designed for race day',
                        body:
                            'Day, night, and red night themes are included so the same device can stay readable from bright daylight through overnight legs.',
                      ),
                      const DocumentSection(
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
                  subtitle:
                      'How connection data, AIS data, and GPS data are handled',
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
                  subtitle:
                      'Usage expectations, limitations, and operator responsibility',
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
                const Divider(height: 1),
                _SettingsActionTile(
                  icon: Icons.play_circle_outline,
                  title: 'Replay Help Tour',
                  subtitle: 'Walk through the dashboard controls again',
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pop(AppSettingsScreen.replayTourResult);
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

class _OwnBoatColorOption {
  final String label;
  final Color color;

  const _OwnBoatColorOption(this.label, this.color);
}

const _ownBoatColorOptions = [
  _OwnBoatColorOption('Teal', Color(0xFF14B8A6)),
  _OwnBoatColorOption('Blue', Color(0xFF2563EB)),
  _OwnBoatColorOption('Orange', Color(0xFFF97316)),
  _OwnBoatColorOption('Gold', Color(0xFFEAB308)),
  _OwnBoatColorOption('Rose', Color(0xFFE11D48)),
  _OwnBoatColorOption('Purple', Color(0xFF8B5CF6)),
];

class _BoatColorChip extends StatelessWidget {
  final _OwnBoatColorOption option;
  final bool selected;
  final VoidCallback onTap;

  const _BoatColorChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? option.color.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.45,
                ),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? option.color : theme.dividerColor,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(option.label),
          ],
        ),
      ),
    );
  }
}

class _OwnBoatPreview extends StatelessWidget {
  final String name;
  final String profileLabel;
  final Color color;

  const _OwnBoatPreview({
    required this.name,
    required this.profileLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = color.computeLuminance() > 0.45
        ? Colors.black
        : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.navigation, color: color, size: 24),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Own Vessel' : name,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (profileLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    profileLabel,
                    style: TextStyle(
                      color: foreground.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
