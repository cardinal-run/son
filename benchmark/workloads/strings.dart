import '../workload.dart';

void main() => runWorkload(
      [for (var i = 0; i < 5000; i++) 'string number ${i % 50}'],
      withDictionary: true,
    );
