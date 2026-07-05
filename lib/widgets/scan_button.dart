import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart' hide ConnectionState;
import '../models/fleet_manager.dart' as fm;

/// Strava-style record button pinned below the dashboard: a big round
/// START button that opens the NMEA connection, turning into a pulsing
/// STOP button while scanning.
class ScanButtonBar extends StatefulWidget {
  const ScanButtonBar({super.key});

  @override
  State<ScanButtonBar> createState() => _ScanButtonBarState();
}

class _ScanButtonBarState extends State<ScanButtonBar>
    with SingleTickerProviderStateMixin {
  static const _buttonSize = 84.0;
  static const _pulseReach = 34.0;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();
    final scheme = Theme.of(context).colorScheme;
    final state = fleet.connectionState;

    final scanning = state == fm.ConnectionState.connected;
    final connecting = state == fm.ConnectionState.connecting ||
        state == fm.ConnectionState.reconnecting;
    final paused = state == fm.ConnectionState.paused;

    if (scanning && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!scanning && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }

    final fillColor = scanning
        ? scheme.error
        : paused
            ? scheme.secondary
            : scheme.primary;
    final labelColor = scanning
        ? scheme.onError
        : paused
            ? scheme.onSecondary
            : scheme.onPrimary;

    final Widget label;
    if (connecting) {
      label = SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 3, color: labelColor),
      );
    } else {
      label = Text(
        scanning
            ? 'PAUSE'
            : paused
                ? 'RESUME'
                : 'START',
        style: TextStyle(
          color: labelColor,
          fontWeight: FontWeight.w800,
          fontSize: paused ? 13 : 16,
          letterSpacing: 2,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: _buttonSize + _pulseReach * 2,
                height: _buttonSize + 16,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    if (scanning)
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          final t = _pulse.value;
                          return Container(
                            width: _buttonSize + _pulseReach * 2 * t,
                            height: _buttonSize + _pulseReach * 2 * t,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: fillColor.withValues(
                                  alpha: (1 - t) * 0.5,
                                ),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    // Static outer ring, Strava-style.
                    Container(
                      width: _buttonSize + 12,
                      height: _buttonSize + 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: fillColor.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                    ),
                    Material(
                      shape: const CircleBorder(),
                      color: fillColor,
                      elevation: 3,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: scanning
                            ? fleet.pause
                            : connecting
                                ? fleet.disconnect
                                : fleet.connect,
                        child: SizedBox(
                          width: _buttonSize,
                          height: _buttonSize,
                          child: Center(child: label),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _caption(fleet, state),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: state == fm.ConnectionState.error
                          ? scheme.error
                          : null,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _caption(FleetManager fleet, fm.ConnectionState state) {
    switch (state) {
      case fm.ConnectionState.connected:
        return 'Scanning ${fleet.host}:${fleet.port} — '
            '${fleet.messageCount} messages';
      case fm.ConnectionState.connecting:
        return 'Connecting to ${fleet.host}:${fleet.port}…';
      case fm.ConnectionState.reconnecting:
        return 'Connection lost — retrying '
            '(${fleet.reconnectAttempts}/${FleetManager.maxReconnectAttempts})…';
      case fm.ConnectionState.paused:
        return 'Paused — ${fleet.messageCount} messages so far, '
            'tap to resume';
      case fm.ConnectionState.error:
        return 'Connection failed — check host in Settings';
      case fm.ConnectionState.disconnected:
        return 'Tap to scan for AIS traffic';
    }
  }
}
