/// Masks secrets and personal data before anything is written to logs,
/// artifacts or bug reports.
///
/// Every log line and every exported text file passes through [redact], so a
/// secret must never appear in diagnostics even if a caller forgets to mask it.
class Redactor {
  Redactor({Iterable<String> secrets = const [], this.homeDir}) {
    secrets.forEach(addSecret);
  }

  static const mask = '***';

  /// Values shorter than this are not registered: masking them would mangle
  /// ordinary text without protecting anything.
  static const minSecretLength = 6;

  /// Replaced by `%USERPROFILE%` in all output.
  final String? homeDir;
  final Set<String> _secrets = {};

  /// JSON keys whose values are always masked.
  static final RegExp sensitiveKey = RegExp(
    r'(api[_-]?key|apikey|token|secret|password|passwd|authorization|cookie|credential|private[_-]?key)',
    caseSensitive: false,
  );

  static final List<(RegExp, String Function(Match))> _patterns = [
    // OpenAI / OpenRouter / Anthropic style keys: sk-..., sk-or-v1-..., sk-ant-...
    (RegExp(r'sk-[A-Za-z0-9_\-]{16,}'), (_) => mask),
    // Google API keys.
    (RegExp(r'AIza[0-9A-Za-z_\-]{30,}'), (_) => mask),
    // Authorization headers.
    (
      RegExp(r'(bearer|basic)\s+[A-Za-z0-9._~+/=\-]{8,}', caseSensitive: false),
      (m) => '${m[1]} $mask',
    ),
    // key=value / "key": "value" pairs with a sensitive key name.
    (
      RegExp(
        r'''((?:api[_-]?key|apikey|access[_-]?token|refresh[_-]?token|token|secret|password|authorization)["']?\s*[:=]\s*["']?)(?!(?:bearer|basic)\s)([^"'\s,&}]+)''',
        caseSensitive: false,
      ),
      (m) => '${m[1]}$mask',
    ),
    // ?key=... query parameters (Google REST APIs).
    (
      RegExp(r'([?&]key=)[^&\s"]+', caseSensitive: false),
      (m) => '${m[1]}$mask',
    ),
    // E-mail addresses.
    (
      RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'),
      (_) => '<email>',
    ),
  ];

  /// Registers a concrete secret value (e.g. every value read from secure
  /// storage) so that it is masked wherever it appears.
  void addSecret(String? value) {
    if (value == null) return;
    final trimmed = value.trim();
    if (trimmed.length >= minSecretLength) _secrets.add(trimmed);
  }

  String redact(String input) {
    var out = input;
    // Longest first so that a secret containing another one is fully masked.
    final secrets = _secrets.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final s in secrets) {
      out = out.replaceAll(s, mask);
    }
    for (final (re, replace) in _patterns) {
      out = out.replaceAllMapped(re, replace);
    }
    final home = homeDir;
    if (home != null && home.isNotEmpty) {
      out = _replaceHome(out, home);
    }
    return out;
  }

  /// Recursively redacts a JSON-like value. Values under sensitive keys are
  /// replaced entirely; strings are passed through [redact].
  Object? redactJson(Object? value) {
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): sensitiveKey.hasMatch(entry.key.toString()) &&
                  entry.value != null &&
                  entry.value is! Map &&
                  entry.value is! List
              ? mask
              : redactJson(entry.value),
      };
    }
    if (value is List) return value.map(redactJson).toList();
    if (value is String) return redact(value);
    return value;
  }

  static String _replaceHome(String input, String home) {
    final variants = <String>{
      home,
      home.replaceAll('\\', '/'),
      home.replaceAll('/', '\\'),
      home.replaceAll('\\', '\\\\'), // JSON-escaped Windows paths
    };
    var out = input;
    for (final v in variants) {
      out = out.replaceAll(RegExp(RegExp.escape(v), caseSensitive: false), '%USERPROFILE%');
    }
    return out;
  }
}
