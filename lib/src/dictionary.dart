import 'dart:collection';
import 'dart:typed_data';

import 'package:son/son.dart';

/// {@template dictionary}
/// Maps strings to integer identifier to minimize the data written.
/// {@endtemplate}
class Dictionary {
  /// {@macro dictionary}
  Dictionary([Map<String, int>? map])
      : _stringToIndex = map ?? HashMap(),
        _indexToString = (map ?? HashMap()).map((k, v) => MapEntry(v, k)),
        _count = map?.length ?? 0;

  /// Map of strings and their indices.
  Map<String, int> get map => _stringToIndex;
  final Map<String, int> _stringToIndex;
  final Map<int, String> _indexToString;

  int _count;

  /// Add the [value] and return it's reference identifier.
  int add(String value) {
    final key = _stringToIndex[value] ??= _count++;
    _indexToString[key] = value;
    return key;
  }

  /// Get a string by it's reference identifier.
  String get(int value) => _indexToString[value]!;

  /// Encode the dictionary to binary using the SON encoder.
  Uint8List toBytes() => const SonEncoder(withDictionary: false).convert(this);
}
