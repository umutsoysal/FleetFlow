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

    if (boats.isNotEmpty && !_hasCentered) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitToFleet(boats);
      });
    }

    return FlutterMap(
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
        MarkerLayer(
          markers: boats.map((boat) => _buildBoatMarker(boat)).toList(),
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

  void _fitToFleet(List<Boat> boats) {
    if (boats.isEmpty) return;

    final lats = boats.map((b) => b.position.latitude).toList();
    final lons = boats.map((b) => b.position.longitude).toList();

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
