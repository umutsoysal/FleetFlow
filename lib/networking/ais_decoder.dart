import 'nmea_parser.dart';

sealed class AISResult {}

class AISPositionReport extends AISResult {
  final int mmsi;
  final int navStatus;
  final double sog;
  final double longitude;
  final double latitude;
  final double cog;
  final double heading;
  final int timestamp;

  AISPositionReport({
    required this.mmsi,
    required this.navStatus,
    required this.sog,
    required this.longitude,
    required this.latitude,
    required this.cog,
    required this.heading,
    required this.timestamp,
  });
}

class AISStaticData extends AISResult {
  final int mmsi;
  final String name;
  final String callSign;
  final int shipType;

  AISStaticData({
    required this.mmsi,
    required this.name,
    required this.callSign,
    required this.shipType,
  });
}

class AISDecoder {
  AISResult? decode(NMEASentence sentence) {
    if (sentence.type != 'VDM' && sentence.type != 'VDO') return null;
    if (sentence.fields.isEmpty) return null;

    final payload = sentence.fields[0];
    final bits = _decodeToBits(payload);
    if (bits.length < 6) return null;

    final messageType = _bitsToUInt(bits, 0, 6);

    switch (messageType) {
      case 1:
      case 2:
      case 3:
        return _decodePositionReport(bits);
      case 5:
        return _decodeStaticData(bits);
      default:
        return null;
    }
  }

  AISPositionReport? _decodePositionReport(List<int> bits) {
    if (bits.length < 168) return null;

    final mmsi = _bitsToUInt(bits, 8, 30);
    final navStatus = _bitsToUInt(bits, 38, 4);
    final rawSOG = _bitsToUInt(bits, 50, 10);
    final sog = rawSOG / 10.0;

    final rawLon = _bitsToSInt(bits, 61, 28);
    final longitude = rawLon / 600000.0;

    final rawLat = _bitsToSInt(bits, 89, 27);
    final latitude = rawLat / 600000.0;

    final rawCOG = _bitsToUInt(bits, 116, 12);
    final cog = rawCOG / 10.0;

    final rawHeading = _bitsToUInt(bits, 128, 9);
    final heading = rawHeading == 511 ? cog : rawHeading.toDouble();

    final timestamp = _bitsToUInt(bits, 137, 6);

    if (longitude < -180 || longitude > 180 || latitude < -90 || latitude > 90) {
      return null;
    }

    return AISPositionReport(
      mmsi: mmsi,
      navStatus: navStatus,
      sog: sog,
      longitude: longitude,
      latitude: latitude,
      cog: cog,
      heading: heading,
      timestamp: timestamp,
    );
  }

  AISStaticData? _decodeStaticData(List<int> bits) {
    if (bits.length < 424) return null;

    final mmsi = _bitsToUInt(bits, 8, 30);
    final callSign = _bitsToString(bits, 70, 42);
    final name = _bitsToString(bits, 112, 120);
    final shipType = _bitsToUInt(bits, 232, 8);

    return AISStaticData(
      mmsi: mmsi,
      name: name,
      callSign: callSign,
      shipType: shipType,
    );
  }

  List<int> _decodeToBits(String payload) {
    final bits = <int>[];
    for (final char in payload.codeUnits) {
      var value = char - 48;
      if (value > 40) value -= 8;
      if (value < 0 || value >= 64) continue;
      for (var i = 5; i >= 0; i--) {
        bits.add((value >> i) & 1);
      }
    }
    return bits;
  }

  int _bitsToUInt(List<int> bits, int start, int length) {
    var value = 0;
    final end = (start + length).clamp(0, bits.length);
    for (var i = start; i < end; i++) {
      value = (value << 1) | bits[i];
    }
    return value;
  }

  int _bitsToSInt(List<int> bits, int start, int length) {
    final unsigned = _bitsToUInt(bits, start, length);
    final signBit = 1 << (length - 1);
    if (unsigned & signBit != 0) {
      return unsigned - (1 << length);
    }
    return unsigned;
  }

  String _bitsToString(List<int> bits, int start, int length) {
    final buffer = StringBuffer();
    final charCount = length ~/ 6;
    for (var i = 0; i < charCount; i++) {
      final charValue = _bitsToUInt(bits, start + i * 6, 6);
      if (charValue == 0) break;
      final asciiValue = charValue < 32 ? charValue + 64 : charValue;
      buffer.writeCharCode(asciiValue);
    }
    return buffer.toString();
  }
}
