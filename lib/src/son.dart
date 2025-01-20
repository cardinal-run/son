import 'dart:convert';
import 'dart:typed_data';

import 'package:son/son.dart';

/// Default SON codec that does not use a dictionary.
const son = Son(withDictionary: false);

/// {@template son}
/// Codec for encoding and decoding SON objects.
/// {@endtemplate}
class Son extends Codec<Object?, Uint8List> {
  ///
  const Son({required bool withDictionary}) : _withDictionary = withDictionary;

  final bool _withDictionary;

  /// Encode the object into the SON format.
  ///
  /// If [withDictionary] is `true`, the encoder will write the strings into a
  /// dictionary defined within the binary data. Otherwise it will write them
  /// in-place.
  ///
  /// If [withDictionary] is not given, it defaults to the `withDictionary`
  /// that was used to instantiate `this`.
  @override
  Uint8List encode(Object? input, {bool? withDictionary}) {
    // Switch between const objects to avoid allocation.
    final encoder = switch (withDictionary ?? _withDictionary) {
      true => const SonEncoder(withDictionary: true),
      false => const SonEncoder(withDictionary: false),
    };
    return encoder.convert(input);
  }

  /// Decodes the SON binary into an Object.
  ///
  /// If [withDictionary] is `true`, the decoder will read the strings from a
  /// dictionary defined within the binary data. Otherwise it will read them
  /// in-place.
  ///
  /// If [withDictionary] is not given, it defaults to the `withDictionary`
  /// that was used to instantiate `this`.
  @override
  Object? decode(Uint8List encoded, {bool? withDictionary}) {
    // Switch between const objects to avoid allocation.
    final decoder = switch (withDictionary ?? _withDictionary) {
      true => const SonDecoder(withDictionary: true),
      false => const SonDecoder(withDictionary: false),
    };
    return decoder.convert(encoded);
  }

  @override
  Converter<Object?, Uint8List> get encoder {
    // Switch between const objects to avoid allocation.
    return switch (_withDictionary) {
      true => const SonEncoder(withDictionary: true),
      false => const SonEncoder(withDictionary: false),
    };
  }

  @override
  Converter<Uint8List, Object?> get decoder {
    // Switch between const objects to avoid allocation.
    return switch (_withDictionary) {
      true => const SonDecoder(withDictionary: true),
      false => const SonDecoder(withDictionary: false),
    };
  }
}
