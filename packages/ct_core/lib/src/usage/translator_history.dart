/// The last requests to translators over the network, as they went and came
/// back (the owner's idea): to see how the model really answers. Kept in
/// `translator_history.json` in the data folder, the last [TranslatorHistory.keep]
/// requests; never the key, never the pictures. Not in the original.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One request to a translator.
class HistoryEntry {
  const HistoryEntry({
    required this.time,
    required this.plugin,
    required this.host,
    required this.model,
    this.page = '',
    this.ms = 0,
    this.sent = '',
    this.image = false,
    this.reply = '',
    this.blocks = 0,
    this.warnings = const [],
    this.error = '',
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cost,
  });

  final DateTime time;
  final String plugin;
  final String host;
  final String model;

  /// The page's name.
  final String page;

  /// How long the answer took.
  final int ms;

  /// The messages as sent (instructions and text), one after another.
  final String sent;

  /// The page image went along (the picture itself is not kept).
  final bool image;

  /// The model's answer as it came, before it was read.
  final String reply;

  /// Bubbles sent.
  final int blocks;

  /// What reading the answer found wrong (missing bubbles, ...).
  final List<String> warnings;

  /// Why the request failed; empty: it was answered.
  final String error;
  final int inputTokens;
  final int outputTokens;

  /// What the service charged (US dollars on OpenRouter); null: not said.
  final double? cost;

  bool get failed => error.isNotEmpty;

  Map<String, Object?> toJson() => {
    'time': time.toIso8601String(),
    'plugin': plugin,
    'host': host,
    'model': model,
    if (page.isNotEmpty) 'page': page,
    'ms': ms,
    'sent': sent,
    if (image) 'image': true,
    'reply': reply,
    'blocks': blocks,
    if (warnings.isNotEmpty) 'warnings': warnings,
    if (error.isNotEmpty) 'error': error,
    if (inputTokens > 0) 'input_tokens': inputTokens,
    if (outputTokens > 0) 'output_tokens': outputTokens,
    if (cost != null) 'cost': cost,
  };

  static HistoryEntry? fromJson(Object? json) {
    if (json is! Map) return null;
    final time = DateTime.tryParse('${json['time']}');
    if (time == null) return null;
    String text(String key) => json[key] is String ? json[key] as String : '';
    int number(String key) => (json[key] as num?)?.toInt() ?? 0;
    return HistoryEntry(
      time: time,
      plugin: text('plugin'),
      host: text('host'),
      model: text('model'),
      page: text('page'),
      ms: number('ms'),
      sent: text('sent'),
      image: json['image'] == true,
      reply: text('reply'),
      blocks: number('blocks'),
      warnings: [...?(json['warnings'] as List?)?.whereType<String>()],
      error: text('error'),
      inputTokens: number('input_tokens'),
      outputTokens: number('output_tokens'),
      cost: (json['cost'] as num?)?.toDouble(),
    );
  }
}

/// Where translators put each request ([PluginContext.reportHistory]).
typedef HistorySink = FutureOr<void> Function(HistoryEntry entry);

/// The history in a JSON file: the newest [keep] requests.
class TranslatorHistory {
  TranslatorHistory(this.file);

  static const keep = 100;

  final File file;
  Future<void> _queue = Future.value();

  /// Adds [entry]; the oldest go past [keep]. Never throws: a history that
  /// cannot be written must not fail a translation.
  Future<void> record(HistoryEntry entry) => _queue = _queue.then((_) async {
    try {
      final entries = [..._load().map((e) => e.toJson()), entry.toJson()];
      final kept = entries.length > keep ? entries.sublist(entries.length - keep) : entries;
      await file.parent.create(recursive: true);
      // Written next to the file and renamed over it: a reader never sees half
      // a file (the window's worker and `cts` may both write).
      final tmp = File('${file.path}.$pid.tmp');
      await tmp.writeAsString(jsonEncode({'version': 1, 'entries': kept}), flush: true);
      try {
        await tmp.rename(file.path);
      } on FileSystemException {
        if (file.existsSync()) await file.delete();
        await tmp.rename(file.path);
      }
    } on Object {
      // Best effort.
    }
  });

  /// Newest first.
  Future<List<HistoryEntry>> read() async {
    await _queue;
    return _load().reversed.toList();
  }

  Future<void> clear() => _queue = _queue.then((_) {
    if (file.existsSync()) file.deleteSync();
  });

  /// Oldest first; a missing or unreadable file is empty.
  List<HistoryEntry> _load() {
    try {
      if (!file.existsSync()) return const [];
      final json = jsonDecode(file.readAsStringSync());
      final list = json is Map ? json['entries'] : null;
      return [for (final e in list is List ? list : const []) ?HistoryEntry.fromJson(e)];
    } on FormatException {
      return const [];
    } on FileSystemException {
      return const [];
    }
  }
}
