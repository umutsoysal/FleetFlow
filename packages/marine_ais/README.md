# marine_ais

Pure Dart AIS decoding for `AIVDM` and `AIVDO` NMEA 0183 sentences.

`marine_ais` validates NMEA checksums, reassembles multipart AIS payloads, and
decodes common position and static-data message types into typed Dart models.

## Install

```yaml
dependencies:
  marine_ais: ^0.1.0
```

## Features

- Validates NMEA checksums
- Reassembles multipart `AIVDM` / `AIVDO` payloads
- Decodes AIS message types `1`, `2`, `3`, `5`, `18`, `19`, and `24`
- Maps AIS "not available" sentinel values to `null`
- Works in Flutter apps, Dart CLIs, and server-side tools

## Supported Messages

- `1`, `2`, `3`: Class A position reports
- `5`: Class A static and voyage data
- `18`: Class B position reports
- `19`: Extended Class B position and static data
- `24`: Class B static data

Unsupported or malformed AIS messages decode to an empty result list.

## Usage

```dart
import 'package:marine_ais/marine_ais.dart';

void main() {
  final codec = AisMessageCodec();

  const line = '!AIVDM,1,1,,A,B52MJh00A6Kg@85wK40N4FhP0000,0*26';
  final results = codec.decodeLine(line);

  for (final result in results) {
    print(result);
  }
}
```

Or use the parser and decoder separately:

```dart
import 'package:marine_ais/marine_ais.dart';

void main() {
  final parser = NmeaParser();
  final decoder = AisDecoder();

  for (final sentence
      in parser.parse('!AIVDM,1,1,,A,B52MJh00A6Kg@85wK40N4FhP0000,0*26')) {
    final results = decoder.decode(sentence);
    print(results);
  }
}
```

Sample output:

```text
AisPositionReport(mmsi: 338123456, navStatus: null, sog: 6.8, longitude: -87.61, latitude: 41.88, cog: 48.1, heading: 45.0, timestamp: 33)
```

## Example

Run the package example:

```bash
dart run example/decode_sentence.dart
```

## Notes

- Unsupported or malformed AIS messages decode to an empty result list.
- The package is pure Dart and can be used from Flutter, CLI, and server apps.
- License: MIT
