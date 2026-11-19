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
        _indexToString = _invert(map);

  /// Map of strings and their indices.
  Map<String, int> get map => _stringToIndex;
  final Map<String, int> _stringToIndex;

  final List<String> _indexToString;

  static List<String> _invert(Map<String, int>? map) {
    final list = List<String>.filled(map?.length ?? 0, '', growable: true);
    map?.forEach((string, index) => list[index] = string);
    return list;
  }

  /// Add the [value] and return it's reference identifier.
  int add(String value) =>
      _stringToIndex[value] ??= (_indexToString..add(value)).length - 1;

  /// Get a string by it's reference identifier.
  String get(int value) => _indexToString[value];

  /// Encode the dictionary to binary using the SON encoder.
  Uint8List toBytes() => const SonEncoder(withDictionary: false).convert(this);
}
