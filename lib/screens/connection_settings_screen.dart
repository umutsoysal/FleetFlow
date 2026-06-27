import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart' hide ConnectionState;
import '../models/fleet_manager.dart' as fm;

class ConnectionSettingsScreen extends StatefulWidget {
  const ConnectionSettingsScreen({super.key});

  @override
  State<ConnectionSettingsScreen> createState() => _ConnectionSettingsScreenState();
}

class _ConnectionSettingsScreenState extends State<ConnectionSettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final fleet = context.read<FleetManager>();
    _hostController = TextEditingController(text: fleet.host);
    _portController = TextEditingController(text: fleet.port.toString());
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Connection Settings',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Connect to B&G Zeus3 or Cortex system via TCP.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
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
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.icon(
                  onPressed: fleet.connectionState != fm.ConnectionState.connected
                      ? () {
                          fleet.host = _hostController.text.trim();
                          fleet.port = int.tryParse(_portController.text) ?? 10110;
                          fleet.connect();
                        }
                      : null,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect'),
                ),
              ),
            ],
          ),
          if (fleet.connectionState == fm.ConnectionState.error)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                fleet.errorMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          _infoRow('Status', fleet.connectionState.label),
          _infoRow('Messages', fleet.messageCount.toString()),
          _infoRow(
            'Last message',
            fleet.lastMessageTime != null
                ? '${DateTime.now().difference(fleet.lastMessageTime!).inSeconds}s ago'
                : '—',
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
