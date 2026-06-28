import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart';
import '../models/boat.dart';

class FleetManagementScreen extends StatefulWidget {
  const FleetManagementScreen({super.key});

  @override
  State<FleetManagementScreen> createState() => _FleetManagementScreenState();
}

class _FleetManagementScreenState extends State<FleetManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();
    final theme = Theme.of(context);

    final fleetBoats = fleet.allDiscoveredBoats
        .where((b) => fleet.isInFleet(b.mmsi))
        .where(_matchesSearch)
        .toList();

    final discoveredBoats = fleet.allDiscoveredBoats
        .where((b) => !fleet.isInFleet(b.mmsi))
        .where(_matchesSearch)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet Manager'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.stars),
              text: 'My Fleet (${fleetBoats.length})',
            ),
            Tab(
              icon: const Icon(Icons.radar),
              text: 'Discovered (${discoveredBoats.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by name or MMSI…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          // Fleet-only toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Show only fleet boats on dashboard',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                Switch.adaptive(
                  value: fleet.fleetOnly,
                  onChanged: (v) => fleet.fleetOnly = v,
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBoatList(
                  context,
                  fleetBoats,
                  isFleetTab: true,
                  emptyMessage: 'No boats in your fleet yet',
                  emptySubtext: 'Go to Discovered tab to add boats',
                ),
                _buildBoatList(
                  context,
                  discoveredBoats,
                  isFleetTab: false,
                  emptyMessage: 'No other boats discovered',
                  emptySubtext: 'Connect to B&G/Cortex to see AIS targets',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(Boat boat) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();
    return boat.displayName.toLowerCase().contains(q) ||
        boat.mmsi.toString().contains(q) ||
        boat.callSign.toLowerCase().contains(q);
  }

  Widget _buildBoatList(
    BuildContext context,
    List<Boat> boats, {
    required bool isFleetTab,
    required String emptyMessage,
    required String emptySubtext,
  }) {
    if (boats.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFleetTab ? Icons.stars_outlined : Icons.radar,
              size: 48,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              emptySubtext,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: boats.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) => _BoatManagementTile(
        boat: boats[index],
        isInFleet: isFleetTab,
      ),
    );
  }
}

class _BoatManagementTile extends StatelessWidget {
  final Boat boat;
  final bool isInFleet;

  const _BoatManagementTile({required this.boat, required this.isInFleet});

  @override
  Widget build(BuildContext context) {
    final fleet = context.read<FleetManager>();
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isInFleet
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.sailing,
            color: isInFleet
                ? theme.colorScheme.onPrimaryContainer
                : Colors.grey,
          ),
        ),
        title: Text(
          boat.displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'MMSI ${boat.mmsi}'
          '${boat.callSign.isNotEmpty ? ' · ${boat.callSign}' : ''}'
          ' · ${boat.speedOverGround.toStringAsFixed(1)} kn'
          ' · ${boat.navigationStatus.label}',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            isInFleet ? Icons.remove_circle_outline : Icons.add_circle_outline,
            color: isInFleet ? Colors.red.shade300 : Colors.green.shade300,
          ),
          tooltip: isInFleet ? 'Remove from fleet' : 'Add to fleet',
          onPressed: () => fleet.toggleFleetMembership(boat.mmsi),
        ),
        isThreeLine: false,
      ),
    );
  }
}
