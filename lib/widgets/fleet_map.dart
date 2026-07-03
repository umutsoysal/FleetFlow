import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart';
import '../models/boat.dart';
import '../models/theme_provider.dart';

class FleetMap extends StatefulWidget {
  const FleetMap({super.key});

  @override
  State<FleetMap> createState() => _FleetMapState();
}

class _FleetMapState extends State<FleetMap> {
  final MapController _mapController = MapController();
  bool _hasCentered = false;

  @override
  Widget build(BuildContext context) {
    final fleet = context.watch<FleetManager>();
    final boats = fleet.activeBoats;

    // Use AIS position when available; only fall back to GPS when no AIS fix.
    final ownPos = fleet.ownPosition;
    final ownName = fleet.ownBoatDisplayName;
    final ownColor = fleet.ownBoatColor;
    if ((boats.isNotEmpty || ownPos != null) && !_hasCentered) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToFleet(boats, ownPos);
      });
    }

    final themeMode = context.watch<ThemeProvider>().mode;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(41.885, -87.618),
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.fleetflow.app',
              tileBuilder: switch (themeMode) {
                AppThemeMode.day => null,
                AppThemeMode.night => _darkTileBuilder,
                AppThemeMode.redNight => _redTileBuilder,
              },
            ),
            if (ownPos != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _circlePoints(ownPos, fleet.coverageRadiusNm * 1852.0),
                    color: _ownBoatRingColor(themeMode, ownColor),
                    strokeWidth: 1.5,
                    pattern: StrokePattern.dashed(segments: [12, 8]),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                ...boats
                    .where((b) => b.mmsi != fleet.ownMmsi)
                    .map((boat) => _buildBoatMarker(boat, themeMode)),
                if (ownPos != null)
                  _buildOwnBoatMarker(
                    ownPos,
                    fleet.ownCourse,
                    fleet.ownSpeed,
                    ownName,
                    themeMode,
                    ownColor,
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: FloatingActionButton.small(
            heroTag: 'fit_fleet',
            tooltip: 'Fit all boats',
            onPressed: boats.isNotEmpty || ownPos != null
                ? () => _fitToFleet(boats, ownPos)
                : null,
            child: const Icon(Icons.fit_screen),
          ),
        ),
      ],
    );
  }

  Widget _darkTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        -0.8, 0, 0, 0, 200,
        0, -0.8, 0, 0, 200,
        0, 0, -0.8, 0, 200,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }

  Widget _redTileBuilder(BuildContext context, Widget tileWidget, TileImage tile) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        0.3, 0.1, 0.1, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: tileWidget,
    );
  }

  Marker _buildBoatMarker(Boat boat, AppThemeMode themeMode) {
    final Color bgColor;
    final Color textColor;
    final Color arrowColor;

    switch (themeMode) {
      case AppThemeMode.day:
        bgColor = Colors.white;
        textColor = const Color(0xFF1A1A1A);
        arrowColor = const Color(0xFFE65100);
      case AppThemeMode.night:
        bgColor = Colors.black87;
        textColor = Colors.white;
        arrowColor = Colors.orangeAccent;
      case AppThemeMode.redNight:
        bgColor = const Color(0xFF1A0000);
        textColor = const Color(0xFFCC4444);
        arrowColor = const Color(0xFFCC3333);
    }

    return Marker(
      point: boat.position,
      width: 100,
      height: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(4),
              border: themeMode == AppThemeMode.day
                  ? Border.all(color: Colors.black26, width: 0.5)
                  : null,
            ),
            child: Text(
              '${boat.displayName}\n${boat.speedOverGround.toStringAsFixed(1)} kn',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          Transform.rotate(
            angle: boat.courseOverGround * math.pi / 180,
            child: Icon(
              Icons.navigation,
              color: arrowColor,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildOwnBoatMarker(
    LatLng position,
    double course,
    double speed,
    String name,
    AppThemeMode themeMode,
    Color accentSeed,
  ) {
    final palette = _ownBoatPalette(themeMode, accentSeed);

    return Marker(
      point: position,
      width: 110,
      height: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.border, width: 1),
            ),
            child: Text(
              '$name\n${speed.toStringAsFixed(1)} kn',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.foreground,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          Transform.rotate(
            angle: course * math.pi / 180,
            child: Icon(
              Icons.navigation,
              color: palette.foreground,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Color _ownBoatRingColor(AppThemeMode themeMode, Color accentSeed) {
    return switch (themeMode) {
      AppThemeMode.day => accentSeed.withValues(alpha: 0.35),
      AppThemeMode.night => _shiftLightness(accentSeed, 0.18).withValues(alpha: 0.4),
      AppThemeMode.redNight => _shiftLightness(accentSeed, 0.1).withValues(alpha: 0.32),
    };
  }

  _OwnBoatPalette _ownBoatPalette(AppThemeMode themeMode, Color accentSeed) {
    switch (themeMode) {
      case AppThemeMode.day:
        return _OwnBoatPalette(
          background: accentSeed,
          foreground: _bestForegroundFor(accentSeed),
          border: _shiftLightness(accentSeed, -0.16),
        );
      case AppThemeMode.night:
        return _OwnBoatPalette(
          background: Color.alphaBlend(
            accentSeed.withValues(alpha: 0.24),
            Colors.black87,
          ),
          foreground: _shiftLightness(accentSeed, 0.2),
          border: _shiftLightness(accentSeed, 0.14),
        );
      case AppThemeMode.redNight:
        return _OwnBoatPalette(
          background: Color.alphaBlend(
            accentSeed.withValues(alpha: 0.18),
            const Color(0xFF120000),
          ),
          foreground: _shiftLightness(accentSeed, 0.16),
          border: _shiftLightness(accentSeed, 0.08),
        );
    }
  }

  Color _shiftLightness(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final nextLightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(nextLightness).toColor();
  }

  Color _bestForegroundFor(Color color) {
    return color.computeLuminance() > 0.45 ? Colors.black : Colors.white;
  }

  /// Generates [steps] points approximating a geodesic circle of [radiusMeters]
  /// around [center] using the spherical Earth model.
  List<LatLng> _circlePoints(LatLng center, double radiusMeters, {int steps = 180}) {
    const R = 6371000.0;
    final lat1 = center.latitude * math.pi / 180;
    final lon1 = center.longitude * math.pi / 180;
    final d = radiusMeters / R;
    final pts = List.generate(steps + 1, (i) {
      final bearing = 2 * math.pi * i / steps;
      final lat2 = math.asin(
        math.sin(lat1) * math.cos(d) +
        math.cos(lat1) * math.sin(d) * math.cos(bearing),
      );
      final lon2 = lon1 + math.atan2(
        math.sin(bearing) * math.sin(d) * math.cos(lat1),
        math.cos(d) - math.sin(lat1) * math.sin(lat2),
      );
      return LatLng(lat2 * 180 / math.pi, lon2 * 180 / math.pi);
    });
    return pts;
  }

  void _fitToFleet(List<Boat> boats, LatLng? ownPosition) {
    final allLats = [
      ...boats.map((b) => b.position.latitude),
      if (ownPosition != null) ownPosition.latitude,
    ];
    final allLons = [
      ...boats.map((b) => b.position.longitude),
      if (ownPosition != null) ownPosition.longitude,
    ];
    if (allLats.isEmpty) return;

    final lats = allLats;
    final lons = allLons;

    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLon = lons.reduce(math.min);
    final maxLon = lons.reduce(math.max);

    final bounds = LatLngBounds(
      LatLng(minLat - 0.01, minLon - 0.01),
      LatLng(maxLat + 0.01, maxLon + 0.01),
    );

    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }
}

class _OwnBoatPalette {
  final Color background;
  final Color foreground;
  final Color border;

  const _OwnBoatPalette({
    required this.background,
    required this.foreground,
    required this.border,
  });
}
