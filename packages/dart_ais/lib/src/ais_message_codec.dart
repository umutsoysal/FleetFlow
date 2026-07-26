import 'ais_decoder.dart';
import 'nmea_parser.dart';

class AisMessageCodec {
  final NmeaParser _parser;
  final AisDecoder _decoder;

  AisMessageCodec({NmeaParser? parser, AisDecoder? decoder})
    : _parser = parser ?? NmeaParser(),
      _decoder = decoder ?? AisDecoder();

  List<AisResult> decodeLine(String line) {
    final results = <AisResult>[];
    for (final sentence in _parser.parse(line)) {
      results.addAll(_decoder.decode(sentence));
    }
    return results;
  }
}
