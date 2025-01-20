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
    final iterator = input.iterator;
    Dictionary? dictionary;

    if (withDictionary) {
      if (!iterator.moveNext()) throw StateError('Excepted next byte');
      dictionary = _convertDictionary((iterator, null));
    }
    return _convert((iterator, dictionary));
  }

  Dictionary _convertDictionary(DecodeContext context) {
    return Dictionary(_convertMap(context).cast());
  }

  Object? _convert(DecodeContext context) {
    while (context.moveNext()) {
      final value = context.current;

      // If the bit at 0 is set, it is some kind of list.
      if (_has(value, 0)) {
        // If the bit at 1 is also set it is a typed data or byte buffer list.
        if (_has(value, 1)) {
          // If any of these positions are set, it is a typed data list.
          if ([4, 5, 6, 7].any((e) => _has(value, e))) {
            return _convertTypedData(context);
          }
          return _convertByteBuffer(context);
        }

        // Not a typed list so it has to be an iterable/list.
        return _convertIterable(context);
      }

      // If the bit at 3 is set, it is a map, string or bool depending on the
      // other bits.
      if (_has(value, 3)) {
        // If the bit at 2 is also set it is a map or string.
        if (_has(value, 2)) {
          // If the bit at 1 is set, it is a map.
          if (_has(value, 1)) return _convertMap(context);
          return _convertString(context);
        }

        // None of the above, it is a bool.
        return _convertBool(context);
      }

      if (_has(value, 2)) return _convertInt(context);
      if (_has(value, 1)) return _convertDouble(context);
    }

    // None of the above, it is nil.
    return null;
  }

  bool _convertBool(DecodeContext context) {
    return _has(context.current, 4);
  }

  int _convertInt(DecodeContext context) {
    final byteData = ByteData(context.current >> 4);
    for (var i = 0; i < byteData.lengthInBytes; i++) {
      if (!context.moveNext()) throw StateError('Excepted next byte');
      byteData.setUint8(i, context.current);
    }
    return switch (byteData.lengthInBytes) {
      1 => byteData.getInt8(0),
      2 => byteData.getInt16(0),
      4 => byteData.getInt32(0),
      8 => byteData.getInt64(0),

      // Unnecessary to test but we still want to throw readable errors to the
      // user.
      // coverage:ignore-start
      _ => throw FormatException(
          'Unexpected byte length: ${byteData.lengthInBytes}',
        )
      // coverage:ignore-end
    };
  }

  double _convertDouble(DecodeContext context) {
    final byteData = ByteData((context.current >> 4) * 4);
    for (var i = 0; i < byteData.lengthInBytes; i++) {
      if (!context.moveNext()) throw StateError('Excepted next byte');
      byteData.setUint8(i, context.current);
    }
    return switch (byteData.lengthInBytes) {
      4 => byteData.getFloat32(0),
      8 => byteData.getFloat64(0),

      // Unnecessary to test but we still want to throw readable errors to the
      // user.
      // coverage:ignore-start
      _ => throw FormatException(
          'Unexpected byte length: ${byteData.lengthInBytes}',
        )
      // coverage:ignore-end
    };
  }

  String _convertString(DecodeContext context) {
    if (withDictionary && context.dictionary != null) {
      final index = _convertUint(context);
      return context.dictionary!.get(index);
    } else {
      var length = context.current >> 4;
      if (length == 0) length = _convertUint(context);

      final byteData = ByteData(length);
      for (var i = 0; i < byteData.lengthInBytes; i++) {
        if (!context.moveNext()) throw StateError('Excepted next byte');
        byteData.setUint8(i, context.current);
      }

      return utf8.decode(byteData.buffer.asUint8List());
    }
  }

  Map<dynamic, dynamic> _convertMap(DecodeContext context) {
    var length = context.current >> 4;
    if (length == 0) length = _convertUint(context);

    return {
      for (var i = 0; i < length; i++) _convert(context): _convert(context),
    };
  }

  Iterable<dynamic> _convertIterable(DecodeContext context) {
    final length = _convertUint(context);
    return [for (var i = 0; i < length; i++) _convert(context)];
  }

  TypedData _convertTypedData(DecodeContext context) {
    final type = context.current >> 4;
    final length = _convertUint(context);
    final byteData = ByteData(length);
    for (var i = 0; i < byteData.lengthInBytes; i++) {
      if (!context.moveNext()) throw StateError('Excepted next byte');
      byteData.setUint8(i, context.current);
    }

    return switch (type) {
      1 => byteData.buffer.asUint8List(),
      2 => byteData.buffer.asUint16List(),
      3 => byteData.buffer.asUint32List(),
      4 => byteData.buffer.asUint64List(), //

      5 => byteData.buffer.asInt8List(),
      6 => byteData.buffer.asInt16List(),
      7 => byteData.buffer.asInt32List(),
      8 => byteData.buffer.asInt64List(), //

      9 => byteData.buffer.asFloat32List(),
      10 => byteData.buffer.asFloat64List(), //

      11 => byteData.buffer.asFloat32x4List(),
      12 => byteData.buffer.asFloat64x2List(),
      13 => byteData.buffer.asInt32x4List(), //

      // Unnecessary to test but we still want to throw readable errors to the
      // user.
      // coverage:ignore-start
      _ => throw FormatException('Unexpected type for typed data: $type'),
      // coverage:ignore-end
    };
  }

  ByteBuffer _convertByteBuffer(DecodeContext context) {
    final length = _convertUint(context);
    final byteData = ByteData(length);
    for (var i = 0; i < byteData.lengthInBytes; i++) {
      if (!context.moveNext()) throw StateError('Excepted next byte');
      byteData.setUint8(i, context.current);
    }
    return byteData.buffer;
  }

  int _convertUint(DecodeContext context) {
    if (!context.moveNext()) throw StateError('Excepted next byte');

    final byteData = ByteData(context.current >> 4);
    for (var i = 0; i < byteData.lengthInBytes; i++) {
      if (!context.moveNext()) throw StateError('Excepted next byte');
      byteData.setUint8(i, context.current);
    }
    return switch (byteData.lengthInBytes) {
      1 => byteData.getUint8(0),
      2 => byteData.getUint16(0),

      // Untested but follows the same logic as above.
      // coverage:ignore-start
      4 => byteData.getUint32(0),
      8 => byteData.getUint64(0),
      // coverage:ignore-end

      // Unnecessary to test but we still want to throw readable errors to the
      // user.
      // coverage:ignore-start
      _ => throw FormatException(
          'Unexpected byte length: ${byteData.lengthInBytes}',
        )
      // coverage:ignore-end
    };
  }

  static bool _has(int value, int position) => (value & 1 << position) != 0;
}

/// Context used for decoding.
typedef DecodeContext = (
  Iterator<int> iterator,
  Dictionary? dictionary,
);

extension on DecodeContext {
  int get current => $1.current;
  bool moveNext() => $1.moveNext();

  Dictionary? get dictionary => $2;
}
