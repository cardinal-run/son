import 'dart:convert';
import 'dart:typed_data';

import 'package:son/son.dart';
import 'package:son/src/dictionary.dart';

/// {@template son_encoder}
/// Encoder for the SON binary format.
/// {@endtemplate}
class SonEncoder extends Converter<Object?, Uint8List> {
  /// {@macro son_encoder}
  const SonEncoder({required this.withDictionary});

  /// If `true` strings will be encoded into a [Dictionary] and a reference will
  /// be stored instead.
  final bool withDictionary;

  @override
  Uint8List convert(Object? input) {
    if (input is Dictionary) return _convertDictionary(input);
    final writer = _Writer(withDictionary ? Dictionary() : null);
    _convert(input, writer);

    final data = writer.takeBytes();
    final dictionary = writer.dictionary;
    if (dictionary == null) return data;
    return (BytesBuilder(copy: false)
          ..add(dictionary.toBytes())
          ..add(data))
        .takeBytes();
  }

  Uint8List _convertDictionary(Dictionary dictionary) {
    final writer = _Writer(null);
    _convertMap(dictionary.map, writer);
    return writer.takeBytes();
  }

  void _convert(Object? input, _Writer writer) {
    switch (input) {
      case null:
        // 0 0 0 0
        writer.byte(0);
      case bool():
        // 1 0 0 0
        _convertBool(input, writer);
      case int():
        // 0 1 0 0
        _convertInt(input, writer);
      case double():
        // 0 0 1 0
        _convertDouble(input, writer);
      case ByteBuffer():
        // 0 0 1 1 0 0 0 0
        _convertByteBuffer(input, writer);
      case TypedData():
        // 0 0 1 1 x x x x
        _convertTypedData(input, writer);
      case Iterable<dynamic>():
        // 0 0 0 1
        _convertIterable(input, writer);
      case String():
        // 1 1 0 0
        _convertString(input, writer);
      case Map<dynamic, dynamic>():
        // 1 1 1 0
        _convertMap(input, writer);
      default:
        _convertObject(input, writer);
    }
  }

  void _convertBool(bool input, _Writer writer) {
    var header = 1 << 3;
    header |= (input ? 1 : 0) << 4;
    writer.byte(header);
  }

  void _convertInt(int input, _Writer writer) {
    final length = switch (input) {
      <= 127 && >= -128 => 1, // 8 bit,
      <= 32766 && >= -32767 => 2, // 16 bit,
      <= 2147483647 && >= -2147483648 => 4, // 32 bit,
      _ => 8, // 64 bit
    };

    // The length in bytes is also the bit flag: 1 << 4, 1 << 5, ...
    writer
      ..byte(1 << 2 | length << 4)
      ..signed(input, length);
  }

  void _convertDouble(double input, _Writer writer) {
    final fitsFloat32 = writer.fitsFloat32(input);

    var header = 1 << 1;
    header |= fitsFloat32 ? 1 << 4 : 1 << 5;

    writer
      ..byte(header)
      ..float(input, fitsFloat32 ? 4 : 8);
  }

  void _convertString(String input, _Writer writer) {
    var header = 1 << 3;
    header |= 1 << 2;

    final dictionary = writer.dictionary;
    if (withDictionary && dictionary != null) {
      final index = dictionary.add(input);
      writer.byte(header);
      _convertUint(index, writer);
    } else {
      final bytes = utf8.encode(input);
      if (input.isNotEmpty && bytes.length <= 15) {
        header |= (bytes.length << 4) & 0xF0;
        writer.byte(header);
      } else {
        writer.byte(header);
        _convertUint(bytes.length, writer);
      }

      writer.bytes(bytes);
    }
  }

  void _convertMap(Map<dynamic, dynamic> input, _Writer writer) {
    var header = 1 << 3;
    header |= 1 << 2;
    header |= 1 << 1;

    if (input.isNotEmpty && input.length <= 15) {
      header |= (input.length << 4) & 0xF0;
      writer.byte(header);
    } else {
      writer.byte(header);
      _convertUint(input.length, writer);
    }

    for (final entry in input.entries) {
      _convert(entry.key, writer);
      _convert(entry.value, writer);
    }
  }

  void _convertIterable(Iterable<dynamic> input, _Writer writer) {
    const header = 1 << 0;

    writer.byte(header);
    _convertUint(input.length, writer);

    for (final value in input) {
      _convert(value, writer);
    }
  }

  void _convertTypedData(TypedData data, _Writer writer) {
    // Encode that it is a typed data.
    var header = 1 << 0;
    header |= 1 << 1;

    final type = switch (data) {
      Uint8List() => 1,
      Uint16List() => 2,
      Uint32List() => 3,
      Uint64List() => 4, //

      Int8List() => 5,
      Int16List() => 6,
      Int32List() => 7,
      Int64List() => 8, //

      Float32List() => 9,
      Float64List() => 10, //

      Float32x4List() => 11,
      Float64x2List() => 12,
      Int32x4List() => 13,

      // If only TypedList was sealed, this would have been exhaustive
      // matched.
      _ => throw UnimplementedError(), // coverage:ignore-line
    };

    // Encode the type of the typed data list.
    header |= (type << 4) & 0xF0;

    writer.byte(header);
    _convertUint(data.lengthInBytes, writer);

    writer.bytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  void _convertByteBuffer(ByteBuffer input, _Writer writer) {
    var header = 1 << 0;
    header |= 1 << 1;

    writer.byte(header);
    _convertUint(input.lengthInBytes, writer);

    writer.bytes(input.asUint8List());
  }

  void _convertObject(Object? input, _Writer writer) {
    for (final convert in [
      () => ((input as dynamic).toJson as Object? Function())(),
      () => ((input as dynamic).toMap as Object? Function())(),
    ]) {
      try {
        return _convert(convert(), writer);
      } catch (err) {
        if (err is NoSuchMethodError) continue;
        throw SonUnsupportedObjectException(input, cause: err);
      }
    }

    throw SonUnsupportedObjectException(input);
  }

  void _convertUint(int input, _Writer writer) {
    final length = switch (input) {
      <= 0xFF => 1, // 8 bit,
      <= 0xFFFF => 2, // 16 bit,

      // Untested but follows the same logic as above.
      // coverage:ignore-start
      <= 0xFFFFFFFF => 4, // 32 bit,
      _ => 8, // 64 bit
      // coverage:ignore-end
    };

    // The length in bytes is also the bit flag: 1 << 4, 1 << 5, ...
    writer
      ..byte(1 << 2 | length << 4)
      ..unsigned(input, length);
  }
}

class _Writer {
  _Writer(this.dictionary);

  final Dictionary? dictionary;

  // Copying explicit, so that small writes go into one buffer and the scratch
  //can be reused.
  // ignore: avoid_redundant_argument_values
  final _builder = BytesBuilder(copy: true);
  final _scratch = ByteData(8);
  late final _scratchBytes = _scratch.buffer.asUint8List();

  void byte(int value) => _builder.addByte(value);

  void bytes(Uint8List value) => _builder.add(value);

  void signed(int value, int length) {
    switch (length) {
      case 1:
        _scratch.setInt8(0, value);
      case 2:
        _scratch.setInt16(0, value);
      case 4:
        _scratch.setInt32(0, value);
      default:
        _scratch.setInt64(0, value);
    }
    _flush(length);
  }

  void unsigned(int value, int length) {
    switch (length) {
      case 1:
        _scratch.setUint8(0, value);
      case 2:
        _scratch.setUint16(0, value);
      // Untested but follows the same logic as above.
      // coverage:ignore-start
      case 4:
        _scratch.setUint32(0, value);
      default:
        _scratch.setUint64(0, value);
      // coverage:ignore-end
    }
    _flush(length);
  }

  bool fitsFloat32(double value) {
    _scratch.setFloat32(0, value);
    return _scratch.getFloat32(0) == value;
  }

  void float(double value, int length) {
    if (length == 4) {
      _scratch.setFloat32(0, value);
    } else {
      _scratch.setFloat64(0, value);
    }
    _flush(length);
  }

  void _flush(int length) {
    for (var i = 0; i < length; i++) {
      _builder.addByte(_scratchBytes[i]);
    }
  }

  Uint8List takeBytes() => _builder.takeBytes();
}
