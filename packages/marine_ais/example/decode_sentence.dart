import 'package:marine_ais/marine_ais.dart';

void main() {
  final codec = AisMessageCodec();
  const line = '!AIVDM,1,1,,A,B52MJh00A6Kg@85wK40N4FhP0000,0*26';

  final results = codec.decodeLine(line);
  if (results.isEmpty) {
    print('No AIS payload decoded from: $line');
    return;
  }

  for (final result in results) {
    print(result);
  }
}
