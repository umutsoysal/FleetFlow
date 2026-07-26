import 'nmea_sentence.dart';

sealed class AisResult {}

class AisPositionReport extends AisResult {
  final int mmsi;
  final int? navStatus;
  final double? sog;
  final double longitude;
  final double latitude;
  final double? cog;
  final double? heading;
  final int timestamp;

  AisPositionReport({
    required this.mmsi,
    required this.navStatus,
    required this.sog,
    required this.longitude,
    required this.latitude,
    required this.cog,
    required this.heading,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'AisPositionReport('
        'mmsi: $mmsi, navStatus: $navStatus, sog: $sog, '
        'longitude: $longitude, latitude: $latitude, '
        'cog: $cog, heading: $heading, timestamp: $timestamp)';
  }
}

class AisStaticData extends AisResult {
  final int mmsi;
  final String? name;
  final String? callSign;
  final int? shipType;

  AisStaticData({required this.mmsi, this.name, this.callSign, this.shipType});

  @override
  String toString() {
    return 'AisStaticData('
        'mmsi: $mmsi, name: $name, callSign: $callSign, shipType: $shipType)';
  }
}

class AisDecoder {
  List<AisResult> decode(NmeaSentence sentence) {
    if (sentence.type != 'VDM' && sentence.type != 'VDO') return [];
    if (sentence.fields.isEmpty) return [];

    final payload = sentence.fields[0];
    final bits = _decodeToBits(payload);
    if (bits.length < 6) return [];

    final messageType = _bitsToUInt(bits, 0, 6);

    switch (messageType) {
      case 1:
      case 2:
      case 3:
        return _wrap(_decodeClassAPosition(bits));
      case 5:
        return _wrap(_decodeClassAStatic(bits));
      case 18:
        return _wrap(_decodeClassBPosition(bits, minBits: 168));
      case 19:
        return _decodeExtendedClassB(bits);
      case 24:
        return _wrap(_decodeClassBStatic(bits));
      default:
        return [];
    }
  }

  List<AisResult> _wrap(AisResult? result) => result == null ? [] : [result];

  AisPositionReport? _decodeClassAPosition(List<int> bits) {
    if (bits.length < 168) return null;

    return _positionReport(
      bits,
      mmsi: _bitsToUInt(bits, 8, 30),
      navStatus: _bitsToUInt(bits, 38, 4),
      sogStart: 50,
      lonStart: 61,
      latStart: 89,
      cogStart: 116,
      headingStart: 128,
      timestampStart: 137,
    );
  }

  AisPositionReport? _decodeClassBPosition(
    List<int> bits, {
    required int minBits,
  }) {
    if (bits.length < minBits) return null;

    return _positionReport(
      bits,
      mmsi: _bitsToUInt(bits, 8, 30),
      navStatus: null,
      sogStart: 46,
      lonStart: 57,
      latStart: 85,
      cogStart: 112,
      headingStart: 124,
      timestampStart: 133,
    );
  }

  List<AisResult> _decodeExtendedClassB(List<int> bits) {
    if (bits.length < 312) return [];

    final results = <AisResult>[];
    final position = _decodeClassBPosition(bits, minBits: 312);
    if (position != null) results.add(position);

    results.add(
      AisStaticData(
        mmsi: _bitsToUInt(bits, 8, 30),
        name: _bitsToString(bits, 143, 120),
        shipType: _bitsToUInt(bits, 263, 8),
      ),
    );
    return results;
  }

  AisPositionReport? _positionReport(
    List<int> bits, {
    required int mmsi,
    required int? navStatus,
    required int sogStart,
    required int lonStart,
    required int latStart,
    required int cogStart,
    required int headingStart,
    required int timestampStart,
  }) {
    final rawSOG = _bitsToUInt(bits, sogStart, 10);
    final sog = rawSOG == 1023 ? null : rawSOG / 10.0;

    final longitude = _bitsToSInt(bits, lonStart, 28) / 600000.0;
    final latitude = _bitsToSInt(bits, latStart, 27) / 600000.0;

    final rawCOG = _bitsToUInt(bits, cogStart, 12);
    final cog = rawCOG >= 3600 ? null : rawCOG / 10.0;

    final rawHeading = _bitsToUInt(bits, headingStart, 9);
    final heading = rawHeading == 511 ? null : rawHeading.toDouble();

    if (longitude < -180 ||
        longitude > 180 ||
        latitude < -90 ||
        latitude > 90) {
      return null;
    }

    return AisPositionReport(
      mmsi: mmsi,
      navStatus: navStatus,
      sog: sog,
      longitude: longitude,
      latitude: latitude,
      cog: cog,
      heading: heading,
      timestamp: _bitsToUInt(bits, timestampStart, 6),
    );
  }

  AisStaticData? _decodeClassAStatic(List<int> bits) {
    if (bits.length < 424) return null;

    return AisStaticData(
      mmsi: _bitsToUInt(bits, 8, 30),
      name: _bitsToString(bits, 112, 120),
      callSign: _bitsToString(bits, 70, 42),
      shipType: _bitsToUInt(bits, 232, 8),
    );
  }

  AisStaticData? _decodeClassBStatic(List<int> bits) {
    if (bits.length < 160) return null;

    final mmsi = _bitsToUInt(bits, 8, 30);
    final partNumber = _bitsToUInt(bits, 38, 2);

    switch (partNumber) {
      case 0:
        return AisStaticData(mmsi: mmsi, name: _bitsToString(bits, 40, 120));
      case 1:
        if (bits.length < 132) return null;
        return AisStaticData(
          mmsi: mmsi,
          callSign: _bitsToString(bits, 90, 42),
          shipType: _bitsToUInt(bits, 40, 8),
        );
      default:
        return null;
    }
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
