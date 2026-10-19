/// What paid or rate-limited services used: each request as the service
/// reported it, and the totals the program keeps on this computer
/// (`usage.json` in the data folder; never sent anywhere). Not in the
/// original.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One request to a service.
class ServiceUsage {
  const ServiceUsage({
    required this.plugin,
    required this.host,
    required this.model,
    this.requests = 1,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cost,
    this.estimated = false,
  });

  final String plugin;

  /// Server the request went to, e.g. `openrouter.ai`.
  final String host;
  final String model;
  final int requests;
  final int inputTokens;
  final int outputTokens;

  /// What the service charged, in its credits (US dollars on OpenRouter);
  /// null when it does not say.
  final double? cost;

  /// The token counts are guessed from the text length (the server sent
  /// none).
  final bool estimated;

  Map<String, Object?> toJson() => {
        'plugin': plugin,
        'host': host,
        'model': model,
        'requests': requests,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        if (cost != null) 'cost': cost,
        if (estimated) 'estimated': true,
      };
}

/// Where plugins report what a request used ([PluginContext.reportUsage]).
typedef UsageSink = FutureOr<void> Function(ServiceUsage usage);

/// Sums of [ServiceUsage] over a period.
class UsageTotals {
  const UsageTotals({this.requests = 0, this.inputTokens = 0, this.outputTokens = 0, this.cost, this.estimated = false});

  factory UsageTotals.fromJson(Object? json) {
    if (json is! Map) return const UsageTotals();
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    return UsageTotals(
      requests: n('requests'),
      inputTokens: n('input_tokens'),
      outputTokens: n('output_tokens'),
      cost: (json['cost'] as num?)?.toDouble(),
      estimated: json['estimated'] == true,
    );
  }

  final int requests;
  final int inputTokens;
  final int outputTokens;

  /// Sum of the reported costs; null when no request reported one.
  final double? cost;

  /// Some token counts are guesses.
  final bool estimated;

  int get tokens => inputTokens + outputTokens;
  bool get isEmpty => requests == 0;

  UsageTotals add(ServiceUsage u) => UsageTotals(
        requests: requests + u.requests,
        inputTokens: inputTokens + u.inputTokens,
        outputTokens: outputTokens + u.outputTokens,
        cost: u.cost == null ? cost : (cost ?? 0) + u.cost!,
        estimated: estimated || u.estimated,
      );

  Map<String, Object?> toJson() => {
        'requests': requests,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        if (cost != null) 'cost': cost,
        if (estimated) 'estimated': true,
      };
}

/// Totals of one model on one server.
class UsageEntry {
  const UsageEntry({
    required this.plugin,
    required this.host,
    required this.model,
    required this.today,
    required this.total,
    this.lastUsed,
  });

  final String plugin;
  final String host;
  final String model;
  final UsageTotals today;
  final UsageTotals total;
  final DateTime? lastUsed;
}

class UsageReport {
  const UsageReport({this.since, this.entries = const []});

  /// Day the counting started (or was last reset).
  final DateTime? since;

  /// Most recently used first.
  final List<UsageEntry> entries;
}

/// The usage counter in a JSON file. Days older than [keepDays] are
/// dropped; the all-time totals stay until [reset].
class UsageLog {
  UsageLog(this.file, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  static const keepDays = 62;

  final File file;
  final DateTime Function() _clock;
  Future<void> _queue = Future.value();

  /// Adds [usage] to today's and the all-time totals. Never throws: a
  /// counter that cannot be written must not fail a translation.
  Future<void> record(ServiceUsage usage) => _queue = _queue.then((_) async {
        try {
          final data = _load();
          final now = _clock();
          final today = dayKey(now);
          final entries = data['entries'] as Map<String, Object?>;
          final key = '${usage.plugin}|${usage.host}|${usage.model}';
          final entry = (entries[key] as Map?)?.cast<String, Object?>() ??
              {'plugin': usage.plugin, 'host': usage.host, 'model': usage.model};
          entry['total'] = UsageTotals.fromJson(entry['total']).add(usage).toJson();
          final days = (entry['days'] as Map?)?.cast<String, Object?>() ?? {};
          days[today] = UsageTotals.fromJson(days[today]).add(usage).toJson();
          final oldest = dayKey(now.subtract(const Duration(days: keepDays)));
          days.removeWhere((day, _) => day.compareTo(oldest) < 0);
          entry['days'] = days;
          entry['last_used'] = now.toIso8601String();
          entries[key] = entry;
          data['since'] ??= today;
          await _save(data);
        } on Object {
          // The counter is best effort.
        }
      });

  /// The totals of every model, today's by the local date.
  Future<UsageReport> read() async {
    await _queue;
    final data = _load();
    final today = dayKey(_clock());
    final entries = [
      for (final e in (data['entries'] as Map<String, Object?>).values)
        if (e is Map)
          UsageEntry(
            plugin: '${e['plugin'] ?? ''}',
            host: '${e['host'] ?? ''}',
            model: '${e['model'] ?? ''}',
            today: UsageTotals.fromJson((e['days'] as Map?)?[today]),
            total: UsageTotals.fromJson(e['total']),
            lastUsed: DateTime.tryParse('${e['last_used']}'),
          ),
    ]..sort((a, b) => (b.lastUsed ?? DateTime(0)).compareTo(a.lastUsed ?? DateTime(0)));
    return UsageReport(since: DateTime.tryParse('${data['since']}'), entries: entries);
  }

  /// Starts counting from zero.
  Future<void> reset() => _queue = _queue.then((_) {
        if (file.existsSync()) file.deleteSync();
      });

  /// `2026-10-19` (local date).
  static String dayKey(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// A missing or unreadable file counts as empty. Read at once: the file
  /// is small, and the settings show it.
  Map<String, Object?> _load() {
    Map<String, Object?> data = {};
    try {
      if (file.existsSync()) {
        final json = jsonDecode(file.readAsStringSync());
        if (json is Map) data = json.cast<String, Object?>();
      }
    } on FormatException {
      // start again
    } on FileSystemException {
      // start again
    }
    final entries = data['entries'];
    data['entries'] = entries is Map ? entries.cast<String, Object?>() : <String, Object?>{};
    data['version'] = 1;
    return data;
  }

  /// Written next to the file and renamed over it, so a reader never sees
  /// half a file (the GUI worker and `cts` may both count).
  Future<void> _save(Map<String, Object?> data) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.$pid.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert(data), flush: true);
    try {
      await tmp.rename(file.path);
    } on FileSystemException {
      if (file.existsSync()) await file.delete();
      await tmp.rename(file.path);
    }
  }
}
