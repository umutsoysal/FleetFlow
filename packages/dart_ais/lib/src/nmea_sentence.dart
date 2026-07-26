class NmeaSentence {
  final String talker;
  final String type;
  final List<String> fields;
  final String raw;

  NmeaSentence({
    required this.talker,
    required this.type,
    required this.fields,
    required this.raw,
  });

  @override
  String toString() =>
      'NmeaSentence(talker: $talker, type: $type, fields: $fields)';
}
