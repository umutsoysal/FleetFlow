import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'boat.dart';
import '../networking/nmea_connection.dart';
import '../networking/nmea_parser.dart';
import '../networking/ais_decoder.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  paused,
  error;

  String get label {
    switch (this) {
      case disconnected:
        return 'Disconnected';
      case connecting:
        return 'Connecting…';
      case connected:
        return 'Connected';
      case paused:
        return 'Paused';
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

  static const _keyHost = 'nmea_host';
  static const _keyPort = 'nmea_port';
  static const _keyMmsi = 'nmea_mmsi';
  static const _keyCoverage = 'coverage_radius_nm';
  static const _keyGpsSource = 'use_gps_for_own_boat';
  static const _keyFleetMmsis = 'fleet_mmsis';
  static const _keyFleetOnly = 'fleet_only';

  double _coverageRadiusNm = 20;
  double get coverageRadiusNm => _coverageRadiusNm;
  set coverageRadiusNm(double v) {
    _coverageRadiusNm = v;
    notifyListeners();
    _saveSettings();
  }
  DateTime? lastMessageTime;
  int messageCount = 0;

  NMEAConnection? _connection;
  final _parser = NMEAParser();
  final _aisDecoder = AISDecoder();

  int? ownMmsi = 235001001;

  // ── Fleet filtering ──────────────────────────────────────────────────────
  final Set<int> _fleetMmsis = {};
  bool _fleetOnly = false;

  Set<int> get fleetMmsis => Set.unmodifiable(_fleetMmsis);
  bool get fleetOnly => _fleetOnly;

  set fleetOnly(bool value) {
    _fleetOnly = value;
    _saveSettings();
    notifyListeners();
  }

  bool isInFleet(int mmsi) => _fleetMmsis.contains(mmsi);

  void addToFleet(int mmsi) {
    _fleetMmsis.add(mmsi);
    _saveSettings();
    notifyListeners();
  }

  void removeFromFleet(int mmsi) {
    _fleetMmsis.remove(mmsi);
    _saveSettings();
    notifyListeners();
  }

  void toggleFleetMembership(int mmsi) {
    if (_fleetMmsis.contains(mmsi)) {
      _fleetMmsis.remove(mmsi);
    } else {
      _fleetMmsis.add(mmsi);
    }
    _saveSettings();
    notifyListeners();
  }

  List<Boat> get allDiscoveredBoats {
    final list = _boats.values.where((b) => b.mmsi != ownMmsi).toList();
    list.sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
  }

  // ── GPS backup ───────────────────────────────────────────────────────────
  LatLng? _gpsPosition;
  double _gpsCourse = 0;
  double _gpsSpeed = 0;
  StreamSubscription<Position>? _positionSubscription;

  /// The AIS boat for our own vessel, when visible in the stream.
  Boat? get ownBoat {
    if (ownMmsi == null) return null;
    final boat = _boats[ownMmsi];
    return (boat != null && !boat.isStale) ? boat : null;
  }

  /// Best available position: respects [useGpsForOwnBoat].
  LatLng? get ownPosition => useGpsForOwnBoat ? _gpsPosition : (ownBoat?.position ?? _gpsPosition);

  /// Best available course: respects [useGpsForOwnBoat].
  double get ownCourse => useGpsForOwnBoat ? _gpsCourse : (ownBoat?.courseOverGround ?? _gpsCourse);

  /// Best available speed (knots): respects [useGpsForOwnBoat].
  double get ownSpeed => useGpsForOwnBoat ? _gpsSpeed : (ownBoat?.speedOverGround ?? _gpsSpeed);

  /// Display name for the own-boat marker.
  String get ownBoatDisplayName => useGpsForOwnBoat ? 'Own Vessel' : (ownBoat?.displayName ?? 'Own Vessel');

  bool _useGpsForOwnBoat = false;
  bool get useGpsForOwnBoat => _useGpsForOwnBoat;
  set useGpsForOwnBoat(bool v) {
    _useGpsForOwnBoat = v;
    notifyListeners();
    _saveSettings();
  }

  /// Raw GPS position from the device, regardless of AIS.
  LatLng? get gpsPosition => _gpsPosition;

  /// Which source is currently driving the own-boat marker.
  String get ownPositionSource {
    if (useGpsForOwnBoat) return _gpsPosition != null ? 'GPS' : '—';
    if (ownBoat != null) return 'AIS';
    if (_gpsPosition != null) return 'GPS (fallback)';
    return '—';
  }

  FleetManager({SharedPreferences? prefs}) {
    if (prefs != null) {
      host = prefs.getString(_keyHost) ?? host;
      port = prefs.getInt(_keyPort) ?? port;
      ownMmsi = prefs.getInt(_keyMmsi) ?? ownMmsi;
      _coverageRadiusNm = prefs.getDouble(_keyCoverage) ?? _coverageRadiusNm;
      _useGpsForOwnBoat = prefs.getBool(_keyGpsSource) ?? _useGpsForOwnBoat;
      _fleetOnly = prefs.getBool(_keyFleetOnly) ?? false;
      final savedMmsis = prefs.getStringList(_keyFleetMmsis);
      if (savedMmsis != null) {
        _fleetMmsis.addAll(savedMmsis.map((s) => int.tryParse(s)).whereType<int>());
      }
    }
    _startGpsTracking();
    // Scanning is user-initiated from the dashboard to avoid draining
    // data in the background; no auto-connect on launch.
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, host);
    await prefs.setInt(_keyPort, port);
    await prefs.setDouble(_keyCoverage, coverageRadiusNm);
    await prefs.setBool(_keyGpsSource, _useGpsForOwnBoat);
    await prefs.setBool(_keyFleetOnly, _fleetOnly);
    await prefs.setStringList(
      _keyFleetMmsis,
      _fleetMmsis.map((m) => m.toString()).toList(),
    );
    if (ownMmsi != null) {
      await prefs.setInt(_keyMmsi, ownMmsi!);
    } else {
      await prefs.remove(_keyMmsi);
    }
  }

  Future<void> _startGpsTracking() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      _gpsPosition = LatLng(pos.latitude, pos.longitude);
      _gpsCourse = pos.heading;
      _gpsSpeed = pos.speed * 1.94384; // m/s → knots
      notifyListeners();
    });
  }

  ConnectionState get connectionState => _connectionState;
  String get errorMessage => _errorMessage;
  Map<int, Boat> get boats => Map.unmodifiable(_boats);

  List<Boat> get sortedBoats {
    final list = _boats.values.toList();
    list.sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
  }

  List<Boat> get activeBoats {
    var list = sortedBoats.where((b) => !b.isStale && b.mmsi != ownMmsi);
    if (_fleetOnly && _fleetMmsis.isNotEmpty) {
      list = list.where((b) => _fleetMmsis.contains(b.mmsi));
    }
    return list.toList();
  }

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
    _saveSettings();
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

  /// Pause listening: closes the socket so no data is consumed, but keeps
  /// the tracked boats and presents as resumable rather than disconnected.
  void pause() {
    _connection?.disconnect();
    _connection = null;
    _connectionState = ConnectionState.paused;
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

  @override
  void dispose() {
    disconnect();
    _positionSubscription?.cancel();
    super.dispose();
  }
}
