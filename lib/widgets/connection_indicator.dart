import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart' hide ConnectionState;
import '../models/fleet_manager.dart' as fm;

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();

    final Color dotColor;
    switch (fleet.connectionState) {
      case fm.ConnectionState.connected:
        dotColor = Colors.green;
      case fm.ConnectionState.connecting:
        dotColor = Colors.orange;
      case fm.ConnectionState.disconnected:
        dotColor = Colors.grey;
      case fm.ConnectionState.error:
        dotColor = Colors.red;
    }

    return Row(
      mainAxisSize: MainAxisSize.max,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: [
              if (fleet.connectionState == fm.ConnectionState.connected)
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            fleet.connectionState.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
