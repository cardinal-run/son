import 'dart:convert';
import 'dart:typed_data';

import 'package:son/src/dictionary.dart';

/// {@template son_decoder}
/// Decoder for the SON binary format.
/// {@endtemplate}
class SonDecoder extends Converter<Uint8List, Object?> {
  /// {@macro son_decoder}
  const SonDecoder({required this.withDictionary});

  /// If `true` the decoder will retrieve strings from the [Dictionary].
  final bool withDictionary;

  @override
  Object? convert(Uint8List input) {
    final reader = _Reader(input);
    if (withDictionary) {
      reader.dictionary = _convertDictionary(reader);
    }
    return _convert(reader);
  }

  Dictionary _convertDictionary(_Reader reader) {
    return Dictionary(_convertMap(reader, reader.next()).cast());
  }

  Object? _convert(_Reader reader) {
    if (reader.isDone) return null;
    final value = reader.next();

    // If the bit at 0 is set, it is some kind of list.
    if (_has(value, 0)) {
      // If the bit at 1 is also set it is a typed data or byte buffer list.
      if (_has(value, 1)) {
        // If any of the bits at 4 to 7 are set, it is a typed data list.
        if (value & 0xF0 != 0) return _convertTypedData(reader, value);
        return _convertByteBuffer(reader);
      }

      // Not a typed list so it has to be an iterable/list.
      return _convertIterable(reader);
    }

    // If the bit at 3 is set, it is a map, string or bool depending on the
    // other bits.
    if (_has(value, 3)) {
      // If the bit at 2 is also set it is a map or string.
      if (_has(value, 2)) {
        // If the bit at 1 is set, it is a map.
        if (_has(value, 1)) return _convertMap(reader, value);
        return _convertString(reader, value);
      }

      // None of the above, it is a bool.
      return _has(value, 4);
    }

    if (_has(value, 2)) return _convertInt(reader, value);
    if (_has(value, 1)) return _convertDouble(reader, value);

    // None of the above, it is nil.
    return null;
  }

  int _convertInt(_Reader reader, int header) {
    final length = header >> 4;
    final offset = reader.skip(length);
    return switch (length) {
      1 => reader.data.getInt8(offset),
      2 => reader.data.getInt16(offset),
      4 => reader.data.getInt32(offset),
      8 => reader.data.getInt64(offset),

      // Unnecessary to test but we still want to throw readable errors to the
      // user.
      // coverage:ignore-start
      _ => throw FormatException('Unexpected byte length: $length'),
      // coverage:ignore-end
    };
  }

  double _convertDouble(_Reader reader, int header) {
    final length = (header >> 4) * 4;
    final offset = reader.skip(length);
    return switch (length) {
      4 => reader.data.getFloat32(offset),
      8 => reader.data.getFloat64(offset),

      // Unnecessary to test but we still want to throw readable errors to the
      // user.
      // coverage:ignore-start
      _ => throw FormatException('Unexpected byte length: $length'),
      // coverage:ignore-end
    };
  }

  String _convertString(_Reader reader, int header) {
    final dictionary = reader.dictionary;
    if (withDictionary && dictionary != null) {
      return dictionary.get(_convertUint(reader));
    }

    var length = header >> 4;
    if (length == 0) length = _convertUint(reader);
    final offset = reader.skip(length);
    return utf8.decoder.convert(reader.bytes, offset, offset + length);
  }

  Map<dynamic, dynamic> _convertMap(_Reader reader, int header) {
    var length = header >> 4;
    if (length == 0) length = _convertUint(reader);

    return {
      for (var i = 0; i < length; i++) _convert(reader): _convert(reader),
    };
  }

  Iterable<dynamic> _convertIterable(_Reader reader) {
    final length = _convertUint(reader);
    return [for (var i = 0; i < length; i++) _convert(reader)];
  }

  TypedData _convertTypedData(_Reader reader, int header) {
    final type = header >> 4;
    final buffer = _copy(reader, _convertUint(reader));

    return switch (type) {
      1 => buffer.asUint8List(),
      2 => buffer.asUint16List(),
      3 => buffer.asUint32List(),
      4 => buffer.asUint64List(), //

      5 => buffer.asInt8List(),
      6 => buffer.asInt16List(),
      7 => buffer.asInt32List(),
      8 => buffer.asInt64List(), //

      9 => buffer.asFloat32List(),
      10 => buffer.asFloat64List(), //

      11 => buffer.asFloat32x4List(),
      12 => buffer.asFloat64x2List(),
      13 => buffer.asInt32x4List(), //

      // Unnecessary to test but we still want to throw readable errors to the
      // user.
      // coverage:ignore-start
      _ => throw FormatException('Unexpected type for typed data: $type'),
      // coverage:ignore-end
    };
  }

  ByteBuffer _convertByteBuffer(_Reader reader) {
    return _copy(reader, _convertUint(reader));
  }

  /// Copies the next [length] bytes into a new buffer.
  ///
  /// A copy is aligned for the typed views, and does not keep the whole input
  /// alive.
  ByteBuffer _copy(_Reader reader, int length) {
    final offset = reader.skip(length);
    return reader.bytes.sublist(offset, offset + length).buffer;
  }

  int _convertUint(_Reader reader) {
    final length = reader.next() >> 4;
    final offset = reader.skip(length);
    return switch (length) {
      1 => reader.data.getUint8(offset),
      2 => reader.data.getUint16(offset),

      // Untested but follows the same logic as above.
      // coverage:ignore-start
      4 => reader.data.getUint32(offset),
      8 => reader.data.getUint64(offset),
      // coverage:ignore-end

      // Unnecessary to test but we still want to throw readable errors to the
      // user.
      // coverage:ignore-start
      _ => throw FormatException('Unexpected byte length: $length'),
      // coverage:ignore-end
    };
  }

  static bool _has(int value, int position) => (value & 1 << position) != 0;
}

class _Reader {
  _Reader(this.bytes) : data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData data;
  Dictionary? dictionary;
  int _offset = 0;

  bool get isDone => _offset >= bytes.length;

  int next() {
    if (isDone) throw StateError('Excepted next byte');
    return bytes[_offset++];
  }

  /// Skips [length] bytes and returns the offset where they start.
  int skip(int length) {
    final start = _offset;
    if (start + length > bytes.length) {
      throw StateError('Excepted next byte');
    }
    _offset += length;
    return start;
  }
}
