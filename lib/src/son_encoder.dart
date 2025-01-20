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
    final context = (
      input,
      BytesBuilder(copy: false),
      withDictionary ? Dictionary() : null
    );
    _convert(context);
    return context.toBytes();
  }

  Uint8List _convertDictionary(Dictionary dictionary) {
    final data = BytesBuilder(copy: false);
    _convertMap((dictionary.map, data, null));
    return data.toBytes();
  }

  void _convert(EncodeContext<Object?> context) {
    if (context.input == null) {
      // 0 0 0 0
      context.write(0);
    } else if (context is EncodeContext<bool>) {
      // 1 0 0 0
      _convertBool(context);
    } else if (context is EncodeContext<int>) {
      // 0 1 0 0
      _convertInt(context);
    } else if (context is EncodeContext<double>) {
      // 0 0 1 0
      _convertDouble(context);
    } else if (context is EncodeContext<ByteBuffer>) {
      // 0 0 1 1 0 0 0 0
      _convertByteBuffer(context);
    } else if (context is EncodeContext<TypedData>) {
      // 0 0 1 1 x x x x
      _convertTypedData(context);
    } else if (context is EncodeContext<Iterable>) {
      // 0 0 0 1
      _convertIterable(context);
    } else if (context is EncodeContext<String>) {
      // 1 1 0 0
      _convertString(context);
    } else if (context is EncodeContext<Map>) {
      // 1 1 1 0
      _convertMap(context);
    } else {
      _convertObject(context);
    }
  }

  void _convertBool(EncodeContext<bool> context) {
    var header = 1 << 3;
    header |= (context.input ? 1 : 0) << 4;
    context.write(header);
  }

  void _convertInt(EncodeContext<int> context) {
    var header = 1 << 2;
    header |= switch (context.input) {
      <= 127 && >= -128 => 1 << 4, // 8 bit,
      <= 32766 && >= -32767 => 1 << 5, // 16 bit,
      <= 2147483647 && >= -2147483648 => 1 << 6, // 32 bit,
      _ => 1 << 7, // 64 bit
    };

    final byteData = switch (context.input) {
      <= 127 && >= -128 => context.input.int8,
      <= 32766 && >= -32767 => context.input.int16,
      <= 2147483647 && >= -2147483648 => context.input.int32,
      _ => context.input.int64,
    };

    context
      ..write(header)
      ..writeAll(byteData);
  }

  void _convertDouble(EncodeContext<double> context) {
    var header = 1 << 1;
    header |= switch (context.input) {
      >= -2147483648 && <= 2147483647 => 1 << 4, // 32 bit
      _ => 1 << 5, // 64 bit
    };

    final byteData = switch (context.input) {
      >= -2147483648 && <= 2147483647 => context.input.float32,
      _ => context.input.float64,
    };

    context
      ..write(header)
      ..writeAll(byteData);
  }

  void _convertString(EncodeContext<String> context) {
    var header = 1 << 3;
    header |= 1 << 2;

    if (withDictionary && context.dictionary != null) {
      final index = context.dictionary!.add(context.input);
      context.write(header);
      _convertUint(index, context.$2);
    } else {
      final bytes = utf8.encode(context.input);
      if (context.input.isNotEmpty && bytes.length <= 15) {
        header |= (bytes.length << 4) & 0xF0;
        context.write(header);
      } else {
        context.write(header);
        _convertUint(bytes.length, context.$2);
      }

      context.writeAll(bytes);
    }
  }

  void _convertMap(EncodeContext<Map<dynamic, dynamic>> context) {
    var header = 1 << 3;
    header |= 1 << 2;
    header |= 1 << 1;

    if (context.input.isNotEmpty && context.input.length <= 15) {
      header |= (context.input.length << 4) & 0xF0;
      context.write(header);
    } else {
      context.write(header);
      _convertUint(context.input.length, context.$2);
    }

    for (final entry in context.input.entries) {
      _convert(context.from(entry.key));
      _convert(context.from(entry.value));
    }
  }

  void _convertIterable(EncodeContext<Iterable<dynamic>> context) {
    const header = 1 << 0;

    context.write(header);
    _convertUint(context.input.length, context.$2);

    for (final value in context.input) {
      _convert(context.from(value));
    }
  }

  void _convertTypedData(EncodeContext<TypedData> context) {
    final data = context.input;

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

    context.write(header);
    _convertUint(data.lengthInBytes, context.$2);

    context.writeAll(data.buffer.asUint8List());
  }

  void _convertByteBuffer(EncodeContext<ByteBuffer> context) {
    var header = 1 << 0;
    header |= 1 << 1;

    context.write(header);
    _convertUint(context.input.lengthInBytes, context.$2);

    context.writeAll(context.input.asUint8List());
  }

  void _convertObject<T extends Object?>(EncodeContext<T> context) {
    for (final convert in [
      () => ((context.input as dynamic).toJson as Object? Function())(),
      () => ((context.input as dynamic).toMap as Object? Function())(),
    ]) {
      try {
        return _convert(context.from(convert()));
      } catch (err) {
        if (err is NoSuchMethodError) continue;
        throw SonUnsupportedObjectException(context.$1, cause: err);
      }
    }

    throw SonUnsupportedObjectException(context.$1);
  }

  void _convertUint(int input, BytesBuilder builder) {
    var header = 1 << 2;
    header |= switch (input) {
      <= 0xFF => 1 << 4, // 8 bit,
      <= 0xFFFF => 1 << 5, // 16 bit,

      // Untested but follows the same logic as above.
      // coverage:ignore-start
      <= 0xFFFFFFFF => 1 << 6, // 32 bit,
      _ => 1 << 7, // 64 bit
      // coverage:ignore-end
    };

    final byteData = switch (input) {
      <= 0xFF => input.uint8,
      <= 0xFFFF => input.uint16,

      // Untested but follows the same logic as above.
      // coverage:ignore-start
      <= 0xFFFFFFFF => input.uint32,
      _ => input.uint64,
      // coverage:ignore-end
    };

    builder
      ..addByte(header)
      ..add(byteData);
  }
}

extension on int {
  Uint8List get uint8 =>
      Uint8List(1)..buffer.asByteData(0, 1).setUint8(0, this);

  Uint8List get uint16 =>
      Uint8List(2)..buffer.asByteData(0, 2).setUint16(0, this);

  // Untested but follows the same logic as above.
  // coverage:ignore-start
  Uint8List get uint32 =>
      Uint8List(4)..buffer.asByteData(0, 4).setUint32(0, this);

  Uint8List get uint64 =>
      Uint8List(8)..buffer.asByteData(0, 8).setUint64(0, this);
  // coverage:ignore-end

  Uint8List get int8 => Uint8List(1)..buffer.asByteData(0, 1).setInt8(0, this);

  Uint8List get int16 =>
      Uint8List(2)..buffer.asByteData(0, 2).setInt16(0, this);

  Uint8List get int32 =>
      Uint8List(4)..buffer.asByteData(0, 4).setInt32(0, this);

  Uint8List get int64 =>
      Uint8List(8)..buffer.asByteData(0, 8).setInt64(0, this);
}

extension on double {
  Uint8List get float32 =>
      Uint8List(4)..buffer.asByteData(0, 4).setFloat32(0, this);

  Uint8List get float64 =>
      Uint8List(8)..buffer.asByteData(0, 8).setFloat64(0, this);
}

/// Context used for encoding.
typedef EncodeContext<I extends Object?> = (
  I input,
  BytesBuilder data,
  Dictionary? dictionary,
);

extension<I extends Object?> on EncodeContext<I> {
  I get input => $1;
  Dictionary? get dictionary => $3;

  void write(int byte) => $2.addByte(byte);

  void writeAll(Uint8List bytes) => $2.add(bytes);

  EncodeContext<T> from<T extends Object?>(T input) => (input, $2, $3);

  Uint8List toBytes() {
    final builder = BytesBuilder();
    if ($3 != null) builder.add($3!.toBytes());
    builder.add($2.toBytes());
    return builder.toBytes();
  }
}
