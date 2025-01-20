import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:son/son.dart';
import 'package:test/test.dart';

class _EncodableTest {
  _EncodableTest({this.shouldFail = false});

  final bool shouldFail;

  Map<String, dynamic> toMap() {
    return shouldFail ? throw Exception('failed') : {'encodable': 'test'};
  }
}

void main() {
  testEncodeAndDecode('null', null);

  testEncodeAndDecode('false', false);

  testEncodeAndDecode('true', true);

  testEncodeAndDecode('Int8', 0xFF);

  testEncodeAndDecode('Int16', 0xFFFF);

  testEncodeAndDecode('Int32', 0xFFFFFFFF);

  testEncodeAndDecode('Int64', 0x7FFFFFFFFFFFFFFF);

  testEncodeAndDecode('Negative int', -5000);

  testEncodeAndDecode('Float32', 200.5);

  testEncodeAndDecode('Float64', 14435432624364.5);

  testEncodeAndDecode('Short string', '1' * 15);

  testEncodeAndDecode('Long string', '1' * 16);

  testEncodeAndDecode('Small map', {for (var i = 0; i < 15; i++) '$i': i});

  testEncodeAndDecode('Big Map', {for (var i = 0; i < 16; i++) '$i': i});

  testEncodeAndDecode('List', ['hello', 'world']);

  testEncodeAndDecode('Object', _EncodableTest());

  testEncodeAndDecode('Uint8List', Uint8List.fromList(listOf(0)));

  testEncodeAndDecode('Uint16List', Uint16List.fromList(listOf(0)));

  testEncodeAndDecode('Uint32List', Uint32List.fromList(listOf(0)));

  testEncodeAndDecode('Uint64List', Uint64List.fromList(listOf(0)));

  testEncodeAndDecode('Int8List', Int8List.fromList(listOf(0)));

  testEncodeAndDecode('Int16List', Int16List.fromList(listOf(0)));

  testEncodeAndDecode('Int32List', Int32List.fromList(listOf(0)));

  testEncodeAndDecode('Int64List', Int64List.fromList(listOf(0)));

  testEncodeAndDecode('Float32List', Float32List.fromList(listOf(0)));

  testEncodeAndDecode(
    'Float32x4List',
    Float32x4List.fromList(listOf(Float32x4(1, 2, 3, 4))),
  );

  testEncodeAndDecode('Float64List', Float64List.fromList(listOf(0)));

  testEncodeAndDecode(
    'Float64x2List',
    Float64x2List.fromList(listOf(Float64x2(1, 2))),
  );

  testEncodeAndDecode(
    'Int32x4List',
    Int32x4List.fromList(listOf(Int32x4(1, 2, 3, 4))),
  );

  testEncodeAndDecode('ByteBuffer', Uint8List.fromList(listOf(0)).buffer);

  test('can not encode non-codable object', () {
    try {
      son.encode(Object());
      fail('Magically able to encode non-codable objects');
    } catch (err) {
      expect(
        err,
        isA<SonUnsupportedObjectException>().having(
          (err) => err.toString(),
          'toString',
          equals(
            """Converting object did not return an encodable object: Instance of 'Object'""",
          ),
        ),
      );
    }
  });

  test('can not encode failing object', () {
    try {
      son.encode(_EncodableTest(shouldFail: true));
      fail('Magically able to encode failing objects');
    } on Exception catch (err) {
      expect(
        err,
        isA<SonUnsupportedObjectException>().having(
          (err) => err.toString(),
          'toString',
          equals(
            """Converting object to an encodable object failed: Instance of '_EncodableTest'""",
          ),
        ),
      );
    }
  });
}

@isTest
void testEncodeAndDecode<T extends Object?>(String description, T object) {
  return test('Encode/decode $description', () {
    final sonWithoutDictionary = Son(withDictionary: false);
    final sonWithDictionary = Son(withDictionary: true);

    var matcher = isEqualOrType(object);
    if (object is _EncodableTest) {
      matcher = equals(object.toMap());
    }

    expect(
      sonWithoutDictionary.decode(sonWithoutDictionary.encode(object)),
      matcher,
    );
    expect(sonWithDictionary.decode(sonWithDictionary.encode(object)), matcher);
  });
}

Matcher isEqualOrType<O extends Object?>(O object) => _IsEqualOrType(object);

class _IsEqualOrType<O extends Object?> extends Matcher {
  const _IsEqualOrType(this.object);

  final O object;

  @override
  Description describe(Description description) {
    return equals(object).describe(description);
  }

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (equals(object).matches(item, matchState)) {
      return true;
    } else {
      return isA<O>().matches(item, matchState);
    }
  }
}

List<T> listOf<T>(T fill, {int length = 1000}) => List.filled(length, fill);
