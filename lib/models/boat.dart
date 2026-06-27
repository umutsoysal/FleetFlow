import 'package:latlong2/latlong.dart';

class Boat {
  final int mmsi;
  String name;
  String callSign;
  LatLng position;
  double speedOverGround; // knots
  double courseOverGround; // degrees
  double trueHeading; // degrees
  NavigationStatus navigationStatus;
  ShipType shipType;
  DateTime lastUpdate;
  final List<SpeedSample> speedHistory;

  Boat({
    required this.mmsi,
    this.name = '',
    this.callSign = '',
    required this.position,
    this.speedOverGround = 0,
    this.courseOverGround = 0,
    this.trueHeading = 0,
    this.navigationStatus = NavigationStatus.undefined,
    this.shipType = ShipType.notAvailable,
    DateTime? lastUpdate,
    List<SpeedSample>? speedHistory,
  })  : lastUpdate = lastUpdate ?? DateTime.now(),
        speedHistory = speedHistory ?? [];

  String get displayName => name.isEmpty ? 'MMSI $mmsi' : name;

  double get averageSpeed {
    if (speedHistory.isEmpty) return speedOverGround;
    return speedHistory.fold(0.0, (sum, s) => sum + s.speed) /
        speedHistory.length;
  }

  double get maxSpeed {
    if (speedHistory.isEmpty) return speedOverGround;
    return speedHistory.map((s) => s.speed).reduce((a, b) => a > b ? a : b);
  }

  Duration get timeSinceUpdate => DateTime.now().difference(lastUpdate);

  bool get isStale => timeSinceUpdate.inSeconds > 300;

  void addSpeedSample(double speed) {
    speedHistory.insert(0, SpeedSample(speed: speed, timestamp: DateTime.now()));
    if (speedHistory.length > 60) {
      speedHistory.removeRange(60, speedHistory.length);
    }
  }
}

class SpeedSample {
  final double speed;
  final DateTime timestamp;

  SpeedSample({required this.speed, required this.timestamp});
}

enum NavigationStatus {
  underWayEngine,
  atAnchor,
  notUnderCommand,
  restrictedManeuverability,
  constrainedByDraught,
  moored,
  aground,
  engagedInFishing,
  underWaySailing,
  reserved9,
  reserved10,
  reserved11,
  reserved12,
  reserved13,
  aisSART,
  undefined;

  static NavigationStatus fromAIS(int value) {
    if (value >= 0 && value < NavigationStatus.values.length) {
      return NavigationStatus.values[value];
    }
    return NavigationStatus.undefined;
  }

  String get label {
    switch (this) {
      case underWayEngine:
        return 'Motoring';
      case atAnchor:
        return 'Anchored';
      case notUnderCommand:
        return 'NUC';
      case restrictedManeuverability:
        return 'Restricted';
      case constrainedByDraught:
        return 'Constrained';
      case moored:
        return 'Moored';
      case aground:
        return 'Aground';
      case engagedInFishing:
        return 'Fishing';
      case underWaySailing:
        return 'Sailing';
      default:
        return 'Unknown';
    }
  }
}

enum ShipType {
  notAvailable,
  sailingVessel,
  pleasureCraft,
  other;

  static ShipType fromAIS(int value) {
    switch (value) {
      case 36:
        return ShipType.sailingVessel;
      case 37:
        return ShipType.pleasureCraft;
      default:
        return ShipType.other;
    }
  }

  String get label {
    switch (this) {
      case notAvailable:
        return 'N/A';
      case sailingVessel:
        return 'Sailboat';
      case pleasureCraft:
        return 'Pleasure';
      case other:
        return 'Other';
    }
  }
}
