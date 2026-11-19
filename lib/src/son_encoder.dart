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
      case String():
        // 1 1 0 0
        _convertString(input, writer);
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
    writer.signed(1 << 2 | length << 4, input, length);
  }

  void _convertDouble(double input, _Writer writer) {
    const header = 1 << 1;
    writer.float(header | 1 << 4, header | 1 << 5, input);
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
      final bytes = _isAscii(input) ? null : utf8.encode(input);
      final length = bytes?.length ?? input.length;
      if (input.isNotEmpty && length <= 15) {
        header |= (length << 4) & 0xF0;
        writer.byte(header);
      } else {
        writer.byte(header);
        _convertUint(length, writer);
      }

      if (bytes == null) {
        writer.ascii(input);
      } else {
        writer.bytes(bytes);
      }
    }
  }

  static bool _isAscii(String input) {
    for (var i = 0; i < input.length; i++) {
      if (input.codeUnitAt(i) > 0x7F) return false;
    }
    return true;
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

    // forEach does not make a MapEntry per entry, as `entries` does.
    input.forEach((key, value) {
      _convert(key, writer);
      _convert(value, writer);
    });
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
    writer.unsigned(1 << 2 | length << 4, input, length);
  }
}

class _Writer {
  _Writer(this.dictionary);

  final Dictionary? dictionary;

  var _buffer = Uint8List(1024);
  late var _data = ByteData.sublistView(_buffer);
  var _length = 0;

  /// Makes room for [count] more bytes and returns where they start.
  int reserve(int count) {
    final start = _length;
    if (start + count > _buffer.length) {
      var capacity = _buffer.length * 2;
      while (capacity < start + count) {
        capacity *= 2;
      }
      _buffer = Uint8List(capacity)..setRange(0, start, _buffer);
      _data = ByteData.sublistView(_buffer);
    }
    _length += count;
    return start;
  }

  void byte(int value) {
    // Reserve first: it can replace `_buffer`.
    final at = reserve(1);
    _buffer[at] = value;
  }

  void bytes(Uint8List value) {
    final start = reserve(value.length);
    _buffer.setRange(start, start + value.length, value);
  }

  /// Writes the code units of [value], which must be ASCII.
  void ascii(String value) {
    final start = reserve(value.length);
    for (var i = 0; i < value.length; i++) {
      _buffer[start + i] = value.codeUnitAt(i);
    }
  }

  /// Writes [header] and then [value] as a signed int of [length] bytes.
  void signed(int header, int value, int length) {
    final at = reserve(1 + length);
    _buffer[at] = header;
    switch (length) {
      case 1:
        _data.setInt8(at + 1, value);
      case 2:
        _data.setInt16(at + 1, value);
      case 4:
        _data.setInt32(at + 1, value);
      default:
        _data.setInt64(at + 1, value);
    }
  }

  /// Writes [header] and then [value] as an unsigned int of [length] bytes.
  void unsigned(int header, int value, int length) {
    final at = reserve(1 + length);
    _buffer[at] = header;
    switch (length) {
      case 1:
        _data.setUint8(at + 1, value);
      case 2:
        _data.setUint16(at + 1, value);
      // Untested but follows the same logic as above.
      // coverage:ignore-start
      case 4:
        _data.setUint32(at + 1, value);
      default:
        _data.setUint64(at + 1, value);
      // coverage:ignore-end
    }
  }

  /// Writes [value] as float32 with [header32] if that keeps its exact value,
  /// otherwise as float64 with [header64].
  void float(int header32, int header64, double value) {
    final at = reserve(9);
    _data.setFloat32(at + 1, value);
    if (_data.getFloat32(at + 1) == value) {
      _buffer[at] = header32;
      _length -= 4;
    } else {
      _buffer[at] = header64;
      _data.setFloat64(at + 1, value);
    }
  }

  /// The view shares the buffer, as `BytesBuilder.takeBytes` does.
  Uint8List takeBytes() => Uint8List.sublistView(_buffer, 0, _length);
}
