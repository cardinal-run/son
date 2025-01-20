import 'dart:convert';
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:son/son.dart';
import 'package:test/test.dart';

void main() {
  testCompression('Compresses null', null, compression: 0.75);

  testCompression('Compresses false', false, compression: 0.8);

  testCompression('Compresses true', true, compression: 0.75);

  testCompression('Compresses uint8', 0xFF, compression: 0);

  testCompression('Compresses uint16', 0xFFFF, compression: 0);

  testCompression('Compresses uint32', 0xFFFFFFFF, compression: 0.10);

  testCompression('Compresses int64', 0x7FFFFFFFFFFFFFFF, compression: 0.52);

  testCompression('Compresses negative int', -5000, compression: 0.40);

  testCompression(
    'Compresses float32',
    0xFFFFFFF.toDouble(),
    compression: 0.54,
  );

  testCompression(
    'Compresses float64',
    0x7FFFFFFFFFFFF.toDouble(),
    compression: 0.5,
  );

  testCompression('Compresses short string', '1' * 15, compression: 0.05);

  testCompression('Compresses long string', '1' * 16, compression: -0.05);

  testCompression(
    'Compresses small map',
    {for (var i = 0; i < 15; i++) '$i': i},
    compression: 0.34,
  );

  testCompression(
    'Compresses big map',
    {for (var i = 0; i < 16; i++) '$i': i},
    compression: 0.33,
  );

  testCompression('Compresses list', ['hello', 'world'], compression: 0.11);

  testCompression(
    'Compresses uint8 list',
    Uint8List.fromList(List.generate(1000, (_) => 0xFF)),
    compression: 0.75,
  );

  testCompression(
    'Compresses uint8 list',
    Uint8List.fromList(List.generate(1000, (_) => 0xFF)),
    compression: 0.75,
  );

  testCompression(
    'Compresses uint16 list',
    Uint16List.fromList(List.generate(1000, (_) => 0xFFFF)),
    compression: 0.66,
  );

  testCompression(
    'Compresses uint32 list',
    Uint32List.fromList(List.generate(1000, (_) => 0xFFFFFFFF)),
    compression: 0.63,
  );

  testCompression(
    'Compresses uint64 list',
    Uint64List.fromList(List.generate(1000, (_) => 0x7FFFFFFFFFFFFFFF)),
    compression: 0.60,
  );

  testCompression(
    'Compresses int8 list',
    Int8List.fromList(List.generate(1000, (_) => 0x7F)),
    compression: 0.75,
  );

  testCompression(
    'Compresses int16 list',
    Int16List.fromList(List.generate(1000, (_) => 0x7FFF)),
    compression: 0.66,
  );

  testCompression(
    'Compresses int32 list',
    Int32List.fromList(List.generate(1000, (_) => 0x7FFFFFFF)),
    compression: 0.63,
  );

  testCompression(
    'Compresses int64 list',
    Int64List.fromList(List.generate(1000, (_) => 0x7FFFFFFFFFFFFFFF)),
    compression: 0.60,
  );

  testCompression(
    'Compresses float32 list',
    Float32List.fromList(List.generate(1000, (_) => 1234.5678)),
    compression: 0.79,
  );

  testCompression(
    'Compresses float32x4 list',
    Float32x4List.fromList(
      List.generate(1000, (_) => Float32x4(12.34, 45.67, 89.01, 23.45)),
    ),
    compression: 0.79,
  );

  testCompression(
    'Compresses float64 list',
    Float64List.fromList(List.generate(1000, (_) => 12345678.98765432)),
    compression: 0.55,
  );

  testCompression(
    'Compresses ByteBuffer',
    Uint8List.fromList(List.generate(1000, (_) => 0xFF)),
    compression: 0.75,
  );
}

@isTest
void testCompression(
  String description,
  Object? object, {
  required double compression,
  bool withDictionarySupport = false,
}) {
  return test(description, () {
    if (object is Float32x4List) {
      return;
    }
    final jsonBytes = json.encode(object);
    final sonBytes = Son(withDictionary: withDictionarySupport).encode(object);
    final compressionPercentage = 1 - sonBytes.length / jsonBytes.length;

    expect(compressionPercentage, closeTo(compression, 0.01));
  });
}
