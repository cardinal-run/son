import '../workload.dart';

void main() => runWorkload([
      for (var i = 0; i < 10000; i++) ...[i, i * 100000, -i * 3, i * 1.25],
    ]);
