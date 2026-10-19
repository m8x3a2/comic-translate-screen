/// Translator failures, sorted by what the user (and a batch run) should do
/// about them.
library;

enum TranslationErrorKind {
  /// The translator is not set up (no server address, no model).
  config,

  /// The server refused the API key (HTTP 401, 403).
  auth,

  /// No money or credits left on the account (HTTP 402).
  credits,

  /// Wrong server address or model name (HTTP 404, unknown model).
  notFound,

  /// Too many requests; the server asks to wait (HTTP 429).
  rateLimit,

  /// The server failed (HTTP 5xx).
  server,

  /// The server cannot be reached (offline, wrong host, connection refused).
  network,

  /// The server did not answer in time.
  timeout,

  /// The reply could not be read (not JSON, unexpected format).
  badReply,

  other;

  /// Every following page would fail the same way: a batch run stops at
  /// once instead of sending the rest.
  bool get stopsRun => const {config, auth, credits, notFound, network}.contains(this);

  /// Worth sending the same request again after a pause.
  bool get isTemporary => const {rateLimit, server, network}.contains(this);

  /// Kind of an HTTP error status; [message] helps with 400, which some
  /// servers (OpenRouter) use for unknown models.
  static TranslationErrorKind forStatus(int status, [String message = '']) => switch (status) {
        401 || 403 => auth,
        402 => credits,
        404 => notFound,
        400 when RegExp(r'\bmodel\b', caseSensitive: false).hasMatch(message) => notFound,
        408 => timeout,
        429 => rateLimit,
        >= 500 => server,
        _ => other,
      };
}

class TranslationException implements Exception {
  TranslationException(this.message, {this.kind = TranslationErrorKind.other, this.statusCode});

  /// Technical details (server answer, host), in English.
  final String message;
  final TranslationErrorKind kind;

  /// HTTP status, when the server answered.
  final int? statusCode;

  @override
  String toString() => 'Translation failed: $message';
}
