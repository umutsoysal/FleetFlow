import 'nmea_parser.dart';

sealed class AISResult {}

class AISPositionReport extends AISResult {
  final int mmsi;

  /// Null for Class B reports, which carry no navigation status.
  final int? navStatus;

  /// Knots; null when the transponder reports "not available" (raw 1023).
  final double? sog;
  final double longitude;
  final double latitude;

  /// Degrees; null when the transponder reports "not available" (raw 3600).
  final double? cog;

  /// Degrees; null when the transponder reports "not available" (raw 511).
  final double? heading;
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

  /// Null when this message type doesn't carry the field (e.g. type 24 part B
  /// has no name, part A has no call sign or ship type).
  final String? name;
  final String? callSign;
  final int? shipType;

  AISStaticData({
    required this.mmsi,
    this.name,
    this.callSign,
    this.shipType,
  });
}

class AISDecoder {
  /// Decodes one reassembled AIS sentence. Returns an empty list for
  /// unsupported or malformed messages; type 19 can yield both a position
  /// report and static data.
  List<AISResult> decode(NMEASentence sentence) {
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

  List<AISResult> _wrap(AISResult? result) => result == null ? [] : [result];

  // Message types 1/2/3: Class A position report.
  AISPositionReport? _decodeClassAPosition(List<int> bits) {
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

  // Message type 18: Class B position report — what most racing sailboats
  // (and the Cortex itself) transmit.
  AISPositionReport? _decodeClassBPosition(List<int> bits,
      {required int minBits}) {
    if (bits.length < minBits) return null;

    return _positionReport(
      bits,
      mmsi: _bitsToUInt(bits, 8, 30),
      navStatus: null, // Class B has no navigation status field
      sogStart: 46,
      lonStart: 57,
      latStart: 85,
      cogStart: 112,
      headingStart: 124,
      timestampStart: 133,
    );
  }

  // Message type 19: extended Class B — position plus name and ship type.
  List<AISResult> _decodeExtendedClassB(List<int> bits) {
    if (bits.length < 312) return [];

    final results = <AISResult>[];
    final position = _decodeClassBPosition(bits, minBits: 312);
    if (position != null) results.add(position);

    results.add(AISStaticData(
      mmsi: _bitsToUInt(bits, 8, 30),
      name: _bitsToString(bits, 143, 120),
      shipType: _bitsToUInt(bits, 263, 8),
    ));
    return results;
  }

  AISPositionReport? _positionReport(
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

    // 181°/91° are the "position not available" sentinels.
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
      timestamp: _bitsToUInt(bits, timestampStart, 6),
    );
  }

  // Message type 5: Class A static and voyage data.
  AISStaticData? _decodeClassAStatic(List<int> bits) {
    if (bits.length < 424) return null;

    return AISStaticData(
      mmsi: _bitsToUInt(bits, 8, 30),
      name: _bitsToString(bits, 112, 120),
      callSign: _bitsToString(bits, 70, 42),
      shipType: _bitsToUInt(bits, 232, 8),
    );
  }

  // Message type 24: Class B static data. Part A carries the name,
  // part B carries call sign and ship type.
  AISStaticData? _decodeClassBStatic(List<int> bits) {
    if (bits.length < 160) return null;

    final mmsi = _bitsToUInt(bits, 8, 30);
    final partNumber = _bitsToUInt(bits, 38, 2);

    switch (partNumber) {
      case 0:
        return AISStaticData(
          mmsi: mmsi,
          name: _bitsToString(bits, 40, 120),
        );
      case 1:
        if (bits.length < 132) return null;
        return AISStaticData(
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
