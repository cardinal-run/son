import 'dart:typed_data';

import '../workload.dart';

void main() => runWorkload(
      Uint8List.fromList(List.generate(1 << 20, (i) => i & 0xFF)),
    );
