import '../workload.dart';

void main() => runWorkload(
      [
        for (var i = 0; i < 1000; i++)
          {
            'id': i,
            'name': 'user $i',
            'score': i / 7,
            'active': i.isEven,
            'tags': ['alpha', 'beta', 'gamma'],
          },
      ],
    );
