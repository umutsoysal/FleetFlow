import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../models/fleet_manager.dart';
import '../models/boat.dart';

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
    if ((boats.isNotEmpty || ownPos != null) && !_hasCentered) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToFleet(boats, ownPos);
      });
    }

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
              tileBuilder: _darkTileBuilder,
            ),
            if (ownPos != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _circlePoints(ownPos, fleet.coverageRadiusNm * 1852.0),
                    color: Colors.cyanAccent.withValues(alpha: 0.35),
                    strokeWidth: 1.5,
                    pattern: StrokePattern.dashed(segments: [12, 8]),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                ...boats
                    .where((b) => b.mmsi != fleet.ownMmsi)
                    .map((boat) => _buildBoatMarker(boat)),
                if (ownPos != null)
                  _buildOwnBoatMarker(ownPos, fleet.ownCourse, fleet.ownSpeed, ownName),
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

  Marker _buildBoatMarker(Boat boat) {
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
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${boat.displayName}\n${boat.speedOverGround.toStringAsFixed(1)} kn',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          Transform.rotate(
            angle: boat.courseOverGround * math.pi / 180,
            child: const Icon(
              Icons.navigation,
              color: Colors.orangeAccent,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildOwnBoatMarker(LatLng position, double course, double speed, String name) {
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
              color: Colors.teal.shade900,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.tealAccent, width: 1),
            ),
            child: Text(
              '$name\n${speed.toStringAsFixed(1)} kn',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.tealAccent,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
          Transform.rotate(
            angle: course * math.pi / 180,
            child: const Icon(
              Icons.navigation,
              color: Colors.tealAccent,
              size: 24,
            ),
          ),
        ],
      ),
    );
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
