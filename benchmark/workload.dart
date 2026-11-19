import 'dart:convert';
import 'dart:io';

import 'package:son/son.dart';

/// Measures encoding and decoding of [input] and prints the results as JSON:
/// `{"encode": µs, "decode": µs}`.
///
/// [withDictionary] picks the mode of the codec. To measure both modes, make
/// one workload per mode.
void runWorkload(Object? input, {bool withDictionary = false}) {
  final codec = Son(withDictionary: withDictionary);
  final encoded = codec.encode(input);
  stdout.writeln(
    jsonEncode({
      'encode': _measure(() => codec.encode(input)),
      'decode': _measure(() => codec.decode(encoded)),
    }),
  );
}

/// Median microseconds per call of [op], over [samples] samples of about
/// [sampleTime] each, after [warmup].
double _measure(
  void Function() op, {
  Duration warmup = const Duration(milliseconds: 300),
  Duration sampleTime = const Duration(milliseconds: 50),
  int samples = 11,
}) {
  final watch = Stopwatch()..start();

  var calls = 0;
  while (watch.elapsed < warmup) {
    op();
    calls++;
  }

  final perSample =
      (calls * sampleTime.inMicroseconds / watch.elapsedMicroseconds)
          .ceil()
          .clamp(1, 1 << 30);

  final times = <double>[];
  for (var s = 0; s < samples; s++) {
    watch.reset();
    for (var i = 0; i < perSample; i++) {
      op();
    }
    times.add(watch.elapsedMicroseconds / perSample);
  }

  return (times..sort())[samples ~/ 2];
}
