import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'boat.dart';
import '../networking/nmea_connection.dart';
import '../networking/nmea_parser.dart';
import '../networking/ais_decoder.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error;

  String get label {
    switch (this) {
      case disconnected:
        return 'Disconnected';
      case connecting:
        return 'Connecting…';
      case connected:
        return 'Connected';
      case error:
        return 'Error';
    }
  }
}

class FleetManager extends ChangeNotifier {
  final Map<int, Boat> _boats = {};
  ConnectionState _connectionState = ConnectionState.disconnected;
  String _errorMessage = '';
  String host = '192.168.1.1';
  int port = 10110;
  DateTime? lastMessageTime;
  int messageCount = 0;

  NMEAConnection? _connection;
  final _parser = NMEAParser();
  final _aisDecoder = AISDecoder();

  ConnectionState get connectionState => _connectionState;
  String get errorMessage => _errorMessage;
  Map<int, Boat> get boats => Map.unmodifiable(_boats);

  List<Boat> get sortedBoats {
    final list = _boats.values.toList();
    list.sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
  }

  List<Boat> get activeBoats => sortedBoats.where((b) => !b.isStale).toList();

  double get fleetAverageSpeed {
    final active = activeBoats;
    if (active.isEmpty) return 0;
    return active.fold(0.0, (sum, b) => sum + b.speedOverGround) /
        active.length;
  }

  double get fleetMaxSpeed {
    final active = activeBoats;
    if (active.isEmpty) return 0;
    return active
        .map((b) => b.speedOverGround)
        .reduce((a, b) => a > b ? a : b);
  }

  void connect() {
    disconnect();
    _connectionState = ConnectionState.connecting;
    notifyListeners();

    _connection = NMEAConnection(
      host: host,
      port: port,
      onData: _handleLine,
      onConnected: () {
        _connectionState = ConnectionState.connected;
        notifyListeners();
      },
      onError: (msg) {
        _connectionState = ConnectionState.error;
        _errorMessage = msg;
        notifyListeners();
      },
      onDisconnected: () {
        _connectionState = ConnectionState.disconnected;
        notifyListeners();
      },
    );
    _connection!.connect();
  }

  void disconnect() {
    _connection?.disconnect();
    _connection = null;
    _connectionState = ConnectionState.disconnected;
    notifyListeners();
  }

  void _handleLine(String line) {
    final sentences = _parser.parse(line);
    for (final sentence in sentences) {
      messageCount++;
      lastMessageTime = DateTime.now();

      final result = _aisDecoder.decode(sentence);
      if (result == null) continue;

      switch (result) {
        case AISPositionReport():
          _updateBoatPosition(result);
        case AISStaticData():
          _updateBoatStatic(result);
      }
    }
    notifyListeners();
  }

  void _updateBoatPosition(AISPositionReport report) {
    final boat = _boats.putIfAbsent(
      report.mmsi,
      () => Boat(
        mmsi: report.mmsi,
        position: LatLng(report.latitude, report.longitude),
      ),
    );

    boat.position = LatLng(report.latitude, report.longitude);
    boat.speedOverGround = report.sog;
    boat.courseOverGround = report.cog;
    boat.trueHeading = report.heading;
    boat.navigationStatus = NavigationStatus.fromAIS(report.navStatus);
    boat.lastUpdate = DateTime.now();
    boat.addSpeedSample(report.sog);
  }

  void _updateBoatStatic(AISStaticData data) {
    final boat = _boats[data.mmsi];
    if (boat == null) return;
    boat.name = data.name.trim();
    boat.callSign = data.callSign.trim();
    boat.shipType = ShipType.fromAIS(data.shipType);
  }

  void injectMockData() {
    final rng = Random();
    final mockBoats = [
      (123456789, 'WIND DANCER', 41.8850, -87.6180, 7.2, 45.0),
      (234567890, 'BLUE HORIZON', 41.8900, -87.6100, 6.8, 52.0),
      (345678901, 'SWIFT CURRENT', 41.8780, -87.6250, 8.1, 38.0),
      (456789012, 'SEA SPIRIT', 41.8920, -87.6050, 5.9, 60.0),
      (567890123, 'WAVE RIDER', 41.8800, -87.6300, 7.5, 42.0),
      (678901234, 'STORM CHASER', 41.8870, -87.6150, 6.3, 55.0),
    ];

    for (final (mmsi, name, lat, lon, sog, cog) in mockBoats) {
      final boat = Boat(
        mmsi: mmsi,
        name: name,
        position: LatLng(lat, lon),
        speedOverGround: sog,
        courseOverGround: cog,
        trueHeading: cog,
        navigationStatus: NavigationStatus.underWaySailing,
        shipType: ShipType.sailingVessel,
      );
      for (var i = 0; i < 10; i++) {
        boat.addSpeedSample(sog + (rng.nextDouble() * 3 - 1.5));
      }
      _boats[mmsi] = boat;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
