# son

[![build](https://github.com/cardinal-run/son/actions/workflows/main.yaml/badge.svg)](https://github.com/cardinal-run/son/actions/workflows/main.yaml)
[![coverage](https://raw.githubusercontent.com/cardinal-run/son/main/coverage_badge.svg)](https://github.com/cardinal-run/son/actions/workflows/main.yaml)
[![pub package](https://img.shields.io/pub/v/son.svg)](https://pub.dev/packages/son)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

A binary encoding format for JSON data that supports a focused subset of Dart types.

## ✨ Features

🤏 Smaller footprint than normal JSON encoded data.

📖 Built-in dictionary support for strings (optional).

🔟 Support for typed data lists like [Float32List](https://api.flutter.dev/flutter/dart-typed_data/Float32List-class.html), [Uint8List](https://api.flutter.dev/flutter/dart-typed_data/Uint8List-class.html) and [others](https://api.flutter.dev/flutter/dart-typed_data/TypedDataList-class.html).

🤖 Automatically encodes Dart classes that have a `toJson` or `toMap` method.

## 🧑‍💻 Example

```dart
import 'dart:typed_data';

import 'package:son/son.dart';

class Funky {
  Map<String, dynamic> toMap() => {'funky': 'stuff'};
}

void main() async {
  final encoded = son.encode({
    'hello': 'world',
    'bytes': Uint8List.fromList([1, 2, 3]),
    'funky': Funky(),
  });
  print('Bytes: $encoded');

  final decoded = son.decode(encoded)! as Map;
  print(decoded['hello'] == 'world'); // true
  print(decoded['bytes'] is Uint8List); // true
  print(decoded['funky'] is Funky); // false, it is a map.
}
```
