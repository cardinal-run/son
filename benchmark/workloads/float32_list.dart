import 'dart:typed_data';

import '../workload.dart';

void main() => runWorkload(
      Float32List.fromList(List.generate(100000, (i) => i / 3)),
    );
