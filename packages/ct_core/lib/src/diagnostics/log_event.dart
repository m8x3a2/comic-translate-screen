enum LogLevel {
  trace,
  debug,
  info,
  warn,
  error;

  static LogLevel parse(String value) =>
      LogLevel.values.firstWhere((l) => l.name == value, orElse: () => LogLevel.info);
}

/// One structured diagnostic event; serialized as one JSONL line.
class LogEvent {
  LogEvent({
    DateTime? ts,
    required this.level,
    required this.event,
    this.runId,
    this.page,
    this.stage,
    this.durMs,
    Map<String, Object?>? data,
  })  : ts = ts ?? DateTime.now(),
        data = data ?? const {};

  final DateTime ts;
  final LogLevel level;

  /// Short machine-readable name, e.g. `stage_end`, `model_download_start`.
  final String event;
  final String? runId;
  final String? page;
  final String? stage;
  final int? durMs;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {
        'ts': ts.toUtc().toIso8601String(),
        'level': level.name,
        'event': event,
        if (runId != null) 'run_id': runId,
        if (page != null) 'page': page,
        if (stage != null) 'stage': stage,
        if (durMs != null) 'dur_ms': durMs,
        if (data.isNotEmpty) 'data': data,
      };

  factory LogEvent.fromJson(Map<String, Object?> json) => LogEvent(
        ts: DateTime.parse(json['ts'] as String),
        level: LogLevel.parse(json['level'] as String),
        event: json['event'] as String,
        runId: json['run_id'] as String?,
        page: json['page'] as String?,
        stage: json['stage'] as String?,
        durMs: json['dur_ms'] as int?,
        data: (json['data'] as Map?)?.cast<String, Object?>(),
      );
}
