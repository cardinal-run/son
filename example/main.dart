// ignore_for_file: avoid_print no need for the example

import 'dart:typed_data';

import 'package:son/son.dart';

class Funky {
  Map<String, dynamic> toMap() => {'funky': 'stuff'};
}

void main() {
  final encoded = son.encode({
    'hello': 'world',
    'bytes': Uint8List.fromList([1, 2, 3]),
    'funky': Funky(),
  });
  print('Bytes: $encoded');

  final decoded = son.decode(encoded)! as Map;
  print(decoded['hello'] == 'world'); // true
  print(decoded['bytes'] is Uint8List); // true
  print(decoded['funky'] is Funky); // false, it is a map.
}
