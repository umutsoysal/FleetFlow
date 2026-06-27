import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart';

class FleetSummaryBar extends StatelessWidget {
  const FleetSummaryBar({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SummaryItem(
            icon: Icons.sailing,
            value: '${fleet.activeBoats.length}',
            label: 'Boats',
          ),
          _SummaryItem(
            icon: Icons.speed,
            value: '${fleet.fleetAverageSpeed.toStringAsFixed(1)} kn',
            label: 'Avg Speed',
          ),
          _SummaryItem(
            icon: Icons.arrow_upward,
            value: '${fleet.fleetMaxSpeed.toStringAsFixed(1)} kn',
            label: 'Max Speed',
          ),
          _SummaryItem(
            icon: Icons.cell_tower,
            value: '${fleet.messageCount}',
            label: 'Messages',
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontFeatures: [const FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
