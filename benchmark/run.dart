import 'dart:convert';
import 'dart:io';
import 'dart:math';

const _rounds = 3;
const _threshold = 0.15;

/// Runs every workload in `benchmark/workloads/` for a base git ref and the
/// working tree, prints the comparison as Markdown, and exits with code 1 if a
/// case is more than [_threshold] slower.
///
/// Usage: `dart run benchmark/run.dart [--base=origin/main] [workload ...]`
Future<void> main(List<String> args) async {
  final baseRef =
      args.where((a) => a.startsWith('--base=')).firstOrNull?.substring(7) ??
          'origin/main';
  final only = args.where((a) => !a.startsWith('--')).toSet();

  // Run everything from the package root, wherever the script started.
  Directory.current = Platform.script.resolve('..').toFilePath();
  final workloads = [
    for (final file in Directory('benchmark/workloads').listSync())
      if (file.path.endsWith('.dart'))
        file.uri.pathSegments.last.replaceAll('.dart', ''),
  ].where((name) => only.isEmpty || only.contains(name)).toList()
    ..sort();
  if (workloads.isEmpty) throw StateError('No workloads found.');

  final temp = Directory.systemTemp.createTempSync('son_benchmark').path;
  final sides = {'base': '$temp/base', 'head': '.'};
  try {
    await _run('git', ['worktree', 'add', '--detach', '$temp/base', baseRef]);
    // Both sides run the workloads of the working tree, so they measure the
    // same thing.
    await _run('rm', ['-rf', '$temp/base/benchmark']);
    await _run('cp', ['-R', 'benchmark', '$temp/base']);

    for (final MapEntry(key: side, value: dir) in sides.entries) {
      await _run('dart', ['pub', 'get'], dir);
      await Future.wait([
        for (final name in workloads)
          _run(
            'dart',
            ['compile', 'exe', 'benchmark/workloads/$name.dart'] +
                ['-o', '$temp/$side-$name.exe'],
            dir,
          ),
      ]);
    }

    // The fastest run per case is used, because noise only makes runs slower.
    final best = {'base': <String, double>{}, 'head': <String, double>{}};
    for (var round = 1; round <= _rounds; round++) {
      for (final name in workloads) {
        stderr.writeln('Round $round/$_rounds: $name');
        for (final side in sides.keys) {
          final out = await _run('$temp/$side-$name.exe', []);
          final json = jsonDecode(out) as Map<String, dynamic>;
          for (final MapEntry(:key, :value) in json.entries) {
            final v = (value as num).toDouble();
            best[side]!
                .update('$name/$key', (old) => min(old, v), ifAbsent: () => v);
          }
        }
      }
    }

    final baseSha =
        (await _run('git', ['rev-parse', '--short', baseRef])).trim();
    final (report, slower) = _report(best['base']!, best['head']!, baseSha);
    stdout.write(report);
    if (slower > 0) exitCode = 1;
  } finally {
    await Process.run('git', ['worktree', 'remove', '--force', '$temp/base']);
    Directory(temp).deleteSync(recursive: true);
  }
}

(String, int) _report(
  Map<String, double> base,
  Map<String, double> head,
  String baseSha,
) {
  // Workload -> operation -> change, in the order of the results.
  final changes = <String, Map<String, double>>{};
  final operations = <String>{};
  for (final MapEntry(key: id, value: h) in head.entries) {
    final slash = id.indexOf('/');
    final workload = id.substring(0, slash);
    final operation = id.substring(slash + 1);
    operations.add(operation);
    (changes[workload] ??= {})[operation] = h / base[id]! - 1;
  }

  // 1 = slower, -1 = faster, 0 = within the threshold.
  int level(double change) =>
      change > _threshold ? 1 : (change < -_threshold ? -1 : 0);
  String math(String tex) => '\$`$tex`\$';
  const symbols = {
    1: r'\color{red}{\blacktriangle}',
    -1: r'\color{green}{\blacktriangledown}',
    0: r'\approx',
  };
  String changeOf(double change) {
    final text = '${change >= 0 ? '+' : '-'}'
        '${(change.abs() * 100).toStringAsFixed(1)}\\%';
    return math(
      switch (level(change)) {
        1 => '\\color{red}{$text}',
        -1 => '\\color{green}{$text}',
        _ => text,
      },
    );
  }

  String cell(String id, double change) =>
      '${_time(head[id]!)}<br>${changeOf(change)}';

  final out = StringBuffer()
    ..writeln('|   | Workload | ${operations.join(' | ')} |')
    ..writeln('| - | --- |${' ---: |' * operations.length}');
  for (final MapEntry(key: workload, value: byOperation) in changes.entries) {
    final levels = byOperation.values.map(level).toSet();
    final row = math(symbols[[1, -1, 0].firstWhere(levels.contains)]!);
    final cells = [
      for (final operation in operations)
        if (byOperation[operation] case final change?)
          cell('$workload/$operation', change)
        else
          '',
    ];
    out.writeln('| $row | $workload | ${cells.join(' | ')} |');
  }

  final slower = changes.values
      .expand((byOperation) => byOperation.values)
      .where((change) => change > _threshold)
      .length;

  final percent = '${(_threshold * 100).round()}%';
  final status = slower == 0
      ? '✅ No case is more than $percent slower than `$baseSha`.'
      : '❌ $slower case(s) are more than $percent slower than `$baseSha`.';

  final details = StringBuffer()
    ..writeln('| Case | Base | Head | Change |')
    ..writeln('| --- | ---: | ---: | ---: |');
  for (final MapEntry(key: id, value: h) in head.entries) {
    final change = h / base[id]! - 1;
    details.writeln(
      '| $id | ${_time(base[id]!)} | ${_time(h)} | '
      '${changeOf(change)} |',
    );
  }

  final report = StringBuffer()
    ..writeln('## 📊 Benchmark')
    ..writeln()
    ..writeln(status)
    ..writeln()
    ..write(out)
    ..writeln()
    ..writeln('<details><summary>Base and head per case</summary>')
    ..writeln()
    ..write(details)
    ..writeln()
    ..writeln('</details>')
    ..writeln()
    ..writeln(
      '<sub>${[
        'Median time per call, fastest of $_rounds rounds',
        '${math(symbols[1]!)} more than $percent slower',
        '${math(symbols[0]!)} within $percent',
        '${math(symbols[-1]!)} more than $percent faster',
      ].join('<br>')}</sub>',
    );
  return (report.toString(), slower);
}

/// Formats [us] microseconds with a unit that keeps it short.
String _time(double us) => switch (us) {
      >= 1e6 => '${(us / 1e6).toStringAsFixed(2)} s',
      >= 1e3 => '${(us / 1e3).toStringAsFixed(2)} ms',
      >= 10 => '${us.toStringAsFixed(0)} µs',
      _ => '${us.toStringAsFixed(1)} µs',
    };

/// Runs [exe] and returns its stdout, or throws if it fails.
Future<String> _run(String exe, List<String> args, [String? dir]) async {
  final result = await Process.run(exe, args, workingDirectory: dir);
  if (result.exitCode != 0) {
    throw ProcessException(exe, args, '${result.stderr}', result.exitCode);
  }
  return result.stdout as String;
}
