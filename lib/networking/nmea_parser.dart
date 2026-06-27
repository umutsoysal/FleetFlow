class NMEASentence {
  final String talker;
  final String type;
  final List<String> fields;
  final String raw;

  NMEASentence({
    required this.talker,
    required this.type,
    required this.fields,
    required this.raw,
  });
}

class NMEAParser {
  final Map<String, Map<int, String>> _multipartBuffer = {};
  final Map<String, int> _multipartTotal = {};

  List<NMEASentence> parse(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return [];
    if (!_validateChecksum(trimmed)) return [];
    if (!trimmed.startsWith('!') && !trimmed.startsWith('\$')) return [];

    final starIdx = trimmed.indexOf('*');
    final body = starIdx >= 0 ? trimmed.substring(1, starIdx) : trimmed.substring(1);
    final fields = body.split(',');

    if (fields.isEmpty || fields[0].length < 5) return [];

    final tag = fields[0];
    final talker = tag.substring(0, 2);
    final type = tag.substring(2);

    final sentence = NMEASentence(
      talker: talker,
      type: type,
      fields: fields.sublist(1),
      raw: trimmed,
    );

    if (type == 'VDM' || type == 'VDO') {
      return _handleMultipart(sentence);
    }

    return [sentence];
  }

  List<NMEASentence> _handleMultipart(NMEASentence sentence) {
    if (sentence.fields.length < 5) return [];

    final totalFragments = int.tryParse(sentence.fields[0]) ?? 1;
    final fragmentNumber = int.tryParse(sentence.fields[1]) ?? 1;
    final messageId = sentence.fields[2];
    final payload = sentence.fields[4];

    if (totalFragments == 1) {
      return [
        NMEASentence(
          talker: sentence.talker,
          type: sentence.type,
          fields: [payload, sentence.fields.length > 5 ? sentence.fields[5] : '0'],
          raw: sentence.raw,
        )
      ];
    }

    final key = '${sentence.type}_$messageId';
    _multipartBuffer.putIfAbsent(key, () => {});
    _multipartBuffer[key]![fragmentNumber] = payload;
    _multipartTotal[key] = totalFragments;

    if (_multipartBuffer[key]!.length == totalFragments) {
      final combined = StringBuffer();
      for (var i = 1; i <= totalFragments; i++) {
        combined.write(_multipartBuffer[key]![i] ?? '');
      }
      _multipartBuffer.remove(key);
      _multipartTotal.remove(key);

      return [
        NMEASentence(
          talker: sentence.talker,
          type: sentence.type,
          fields: [combined.toString(), '0'],
          raw: sentence.raw,
        )
      ];
    }

    return [];
  }

  bool _validateChecksum(String sentence) {
    final starIdx = sentence.indexOf('*');
    if (starIdx < 0) return true; // no checksum to validate

    final body = sentence.substring(1, starIdx);
    final providedHex = sentence.substring(starIdx + 1).trim();
    final provided = int.tryParse(providedHex, radix: 16);
    if (provided == null) return false;

    var checksum = 0;
    for (final c in body.codeUnits) {
      checksum ^= c;
    }

    return checksum == provided;
  }
}
