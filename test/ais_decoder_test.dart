import 'package:flutter_test/flutter_test.dart';
import 'package:fleet_flow/networking/ais_decoder.dart';
import 'package:fleet_flow/networking/nmea_parser.dart';

/// Builds AIS payloads bit-by-bit so tests can round-trip real AIVDM
/// sentences through the parser and decoder.
class BitWriter {
  final List<int> bits = [];

  void uint(int value, int length) {
    for (var i = length - 1; i >= 0; i--) {
      bits.add((value >> i) & 1);
    }
  }

  void sint(int value, int length) => uint(value & ((1 << length) - 1), length);

  /// AIS 6-bit string: '@' (terminator) = 0, 'A'–'_' = 1–31, ' '–'?' = 32–63.
  void str(String s, int length) {
    final charCount = length ~/ 6;
    for (var i = 0; i < charCount; i++) {
      final c = i < s.length ? s.codeUnitAt(i) : 64; // pad with '@'
      uint(c >= 64 ? c - 64 : c, 6);
    }
  }

  void pad(int toLength) {
    while (bits.length < toLength) {
      bits.add(0);
    }
  }
}

String encodePayload(List<int> bits) {
  final padded = List.of(bits);
  while (padded.length % 6 != 0) {
    padded.add(0);
  }
  final sb = StringBuffer();
  for (var i = 0; i < padded.length; i += 6) {
    var v = 0;
    for (var j = 0; j < 6; j++) {
      v = (v << 1) | padded[i + j];
    }
    sb.writeCharCode(v < 40 ? v + 48 : v + 56);
  }
  return sb.toString();
}

String aivdm(String payload, {int total = 1, int frag = 1, String msgId = ''}) {
  final body = 'AIVDM,$total,$frag,$msgId,A,$payload,0';
  var cs = 0;
  for (final c in body.codeUnits) {
    cs ^= c;
  }
  return '!$body*${cs.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}

List<int> buildType1({
  required int mmsi,
  int navStatus = 8,
  int sogRaw = 74,
  double lat = 43.65,
  double lon = -79.38,
  int cogRaw = 2255,
  int headingRaw = 226,
}) {
  final w = BitWriter();
  w.uint(1, 6); // message type
  w.uint(0, 2); // repeat
  w.uint(mmsi, 30);
  w.uint(navStatus, 4);
  w.uint(0, 8); // rate of turn
  w.uint(sogRaw, 10);
  w.uint(0, 1); // accuracy
  w.sint((lon * 600000).round(), 28);
  w.sint((lat * 600000).round(), 27);
  w.uint(cogRaw, 12);
  w.uint(headingRaw, 9);
  w.uint(33, 6); // timestamp
  w.pad(168);
  return w.bits;
}

List<int> buildType18({
  required int mmsi,
  int sogRaw = 68,
  double lat = 41.88,
  double lon = -87.61,
  int cogRaw = 481,
  int headingRaw = 45,
}) {
  final w = BitWriter();
  w.uint(18, 6); // message type
  w.uint(0, 2); // repeat
  w.uint(mmsi, 30);
  w.uint(0, 8); // reserved
  w.uint(sogRaw, 10);
  w.uint(0, 1); // accuracy
  w.sint((lon * 600000).round(), 28);
  w.sint((lat * 600000).round(), 27);
  w.uint(cogRaw, 12);
  w.uint(headingRaw, 9);
  w.uint(33, 6); // timestamp
  w.pad(168);
  return w.bits;
}

final _parser = NMEAParser();
final _decoder = AISDecoder();

List<AISResult> decodeBits(List<int> bits) {
  final sentences = _parser.parse(aivdm(encodePayload(bits)));
  expect(sentences, hasLength(1));
  return _decoder.decode(sentences.first);
}

void main() {
  group('Class A position (types 1/2/3)', () {
    test('decodes position, speed, course and nav status', () {
      final results = decodeBits(buildType1(mmsi: 316001234));
      expect(results, hasLength(1));
      final report = results.single as AISPositionReport;

      expect(report.mmsi, 316001234);
      expect(report.navStatus, 8);
      expect(report.sog, closeTo(7.4, 1e-9));
      expect(report.latitude, closeTo(43.65, 1e-6));
      expect(report.longitude, closeTo(-79.38, 1e-6));
      expect(report.cog, closeTo(225.5, 1e-9));
      expect(report.heading, 226);
      expect(report.timestamp, 33);
    });

    test('rejects the "position not available" sentinel (181°/91°)', () {
      final results = decodeBits(buildType1(mmsi: 1, lon: 181, lat: 91));
      expect(results, isEmpty);
    });
  });

  group('Class B position (type 18)', () {
    test('decodes a Class B report with no nav status', () {
      final results = decodeBits(buildType18(mmsi: 338123456));
      expect(results, hasLength(1));
      final report = results.single as AISPositionReport;

      expect(report.mmsi, 338123456);
      expect(report.navStatus, isNull);
      expect(report.sog, closeTo(6.8, 1e-9));
      expect(report.latitude, closeTo(41.88, 1e-6));
      expect(report.longitude, closeTo(-87.61, 1e-6));
      expect(report.cog, closeTo(48.1, 1e-9));
      expect(report.heading, 45);
    });

    test('maps "not available" SOG/COG/heading sentinels to null', () {
      final results = decodeBits(buildType18(
        mmsi: 338123456,
        sogRaw: 1023,
        cogRaw: 3600,
        headingRaw: 511,
      ));
      final report = results.single as AISPositionReport;

      expect(report.sog, isNull);
      expect(report.cog, isNull);
      expect(report.heading, isNull);
    });
  });

  group('Extended Class B (type 19)', () {
    test('yields both a position report and static data', () {
      final w = BitWriter();
      w.uint(19, 6);
      w.uint(0, 2);
      w.uint(338999888, 30);
      w.uint(0, 8); // reserved
      w.uint(102, 10); // SOG 10.2 kn
      w.uint(0, 1);
      w.sint((-87.61 * 600000).round(), 28);
      w.sint((41.88 * 600000).round(), 27);
      w.uint(150, 12);
      w.uint(14, 9);
      w.uint(33, 6); // timestamp → 139
      w.uint(0, 4); // reserved → 143
      w.str('PEGASUS', 120); // name → 263
      w.uint(36, 8); // ship type: sailing
      w.pad(312);

      final results = decodeBits(w.bits);
      expect(results, hasLength(2));

      final report = results.whereType<AISPositionReport>().single;
      expect(report.mmsi, 338999888);
      expect(report.sog, closeTo(10.2, 1e-9));

      final static_ = results.whereType<AISStaticData>().single;
      expect(static_.name, 'PEGASUS');
      expect(static_.shipType, 36);
      expect(static_.callSign, isNull);
    });
  });

  group('Class B static data (type 24)', () {
    List<int> header(int mmsi, int part) {
      final w = BitWriter();
      w.uint(24, 6);
      w.uint(0, 2);
      w.uint(mmsi, 30);
      w.uint(part, 2);
      return w.bits;
    }

    test('part A carries the vessel name', () {
      final w = BitWriter()..bits.addAll(header(338777666, 0));
      w.str('WINDSHADOW', 120);
      w.pad(168);

      final results = decodeBits(w.bits);
      final static_ = results.single as AISStaticData;
      expect(static_.mmsi, 338777666);
      expect(static_.name, 'WINDSHADOW');
      expect(static_.callSign, isNull);
      expect(static_.shipType, isNull);
    });

    test('part B carries ship type and call sign', () {
      final w = BitWriter()..bits.addAll(header(338777666, 1));
      w.uint(36, 8); // ship type: sailing → 48
      w.uint(0, 42); // vendor id → 90
      w.str('VA1234', 42); // call sign → 132
      w.pad(168);

      final results = decodeBits(w.bits);
      final static_ = results.single as AISStaticData;
      expect(static_.mmsi, 338777666);
      expect(static_.name, isNull);
      expect(static_.callSign, 'VA1234');
      expect(static_.shipType, 36);
    });
  });

  group('Class A static data (type 5, multipart)', () {
    test('reassembles two fragments and decodes name/call sign/type', () {
      final w = BitWriter();
      w.uint(5, 6);
      w.uint(0, 2);
      w.uint(316555444, 30); // → 38
      w.uint(0, 2); // AIS version → 40
      w.uint(0, 30); // IMO → 70
      w.str('CFN5678', 42); // call sign → 112
      w.str('NORTHERN LIGHT', 120); // name → 232
      w.uint(36, 8); // ship type → 240
      w.pad(424);

      final payload = encodePayload(w.bits);
      final frag1 = payload.substring(0, 36);
      final frag2 = payload.substring(36);

      expect(
        _parser.parse(aivdm(frag1, total: 2, frag: 1, msgId: '7')),
        isEmpty,
      );
      final sentences = _parser.parse(aivdm(frag2, total: 2, frag: 2, msgId: '7'));
      expect(sentences, hasLength(1));

      final results = _decoder.decode(sentences.first);
      final static_ = results.single as AISStaticData;
      expect(static_.mmsi, 316555444);
      expect(static_.name, 'NORTHERN LIGHT');
      expect(static_.callSign, 'CFN5678');
      expect(static_.shipType, 36);
    });
  });

  group('NMEA parser', () {
    test('rejects sentences with a bad checksum', () {
      final good = aivdm(encodePayload(buildType18(mmsi: 1)));
      final bad = '${good.substring(0, good.length - 2)}00';
      expect(_parser.parse(bad), isEmpty);
    });

    test('ignores unsupported message types', () {
      final w = BitWriter();
      w.uint(21, 6); // aid-to-navigation report
      w.pad(272);
      expect(decodeBits(w.bits), isEmpty);
    });
  });
}
