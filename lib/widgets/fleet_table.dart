import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart';
import '../models/boat.dart';
import 'speed_sparkline.dart';

class FleetTable extends StatelessWidget {
  const FleetTable({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();
    final boats = fleet.activeBoats;

    if (boats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sailing_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text('No boats detected', style: TextStyle(color: Colors.grey)),
            SizedBox(height: 4),
            Text(
              'Connect to B&G/Cortex or your simulator harness',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: boats.length,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemBuilder: (context, index) => _BoatTile(boat: boats[index]),
    );
  }
}

class _BoatTile extends StatelessWidget {
  final Boat boat;

  const _BoatTile({required this.boat});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStale = boat.isStale;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: isStale
          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
          : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sailing,
                  size: 18,
                  color: isStale ? Colors.grey : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    boat.displayName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isStale ? Colors.grey : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(label: boat.navigationStatus.label),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _DataCell(
                  label: 'SOG',
                  value: '${boat.speedOverGround.toStringAsFixed(1)} kn',
                ),
                _DataCell(
                  label: 'AVG',
                  value: '${boat.averageSpeed.toStringAsFixed(1)} kn',
                ),
                _DataCell(
                  label: 'MAX',
                  value: '${boat.maxSpeed.toStringAsFixed(1)} kn',
                ),
                _DataCell(
                  label: 'COG',
                  value: '${boat.courseOverGround.toStringAsFixed(0)}°',
                ),
                _DataCell(
                  label: 'HDG',
                  value: '${boat.trueHeading.toStringAsFixed(0)}°',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SpeedSparkline(
                    samples: boat.lastHourSamples,
                    height: 36,
                    lineColor: _trendColor(boat.speedTrend, theme),
                  ),
                ),
                const SizedBox(width: 8),
                _TrendIndicator(trend: boat.speedTrend),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _trendColor(double? trend, ThemeData theme) {
    if (trend == null) return theme.colorScheme.primary;
    if (trend > 0.3) return Colors.green.shade300;
    if (trend < -0.3) return Colors.red.shade300;
    return theme.colorScheme.primary;
  }
}

class _TrendIndicator extends StatelessWidget {
  final double? trend;

  const _TrendIndicator({required this.trend});

  @override
  Widget build(BuildContext context) {
    if (trend == null) {
      return const SizedBox(width: 40);
    }

    final IconData icon;
    final Color color;
    if (trend! > 0.3) {
      icon = Icons.trending_up;
      color = Colors.green.shade300;
    } else if (trend! < -0.3) {
      icon = Icons.trending_down;
      color = Colors.red.shade300;
    } else {
      icon = Icons.trending_flat;
      color = Colors.grey;
    }

    return SizedBox(
      width: 40,
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          Text(
            '${trend! >= 0 ? '+' : ''}${trend!.toStringAsFixed(1)}',
            style: TextStyle(fontSize: 9, color: color),
          ),
        ],
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String label;
  final String value;

  const _DataCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
