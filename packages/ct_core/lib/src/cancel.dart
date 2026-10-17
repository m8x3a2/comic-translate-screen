/// Cooperative cancellation for long-running operations (batch runs, model
/// downloads). Stages call [throwIfCancelled] between steps.
class CancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final l in List.of(_listeners)) {
      l();
    }
    _listeners.clear();
  }

  /// Runs [listener] on cancellation (immediately if already cancelled).
  void onCancel(void Function() listener) {
    if (_cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
  }

  void throwIfCancelled() {
    if (_cancelled) throw const CancelledException();
  }

  /// A token that is never cancelled.
  static final CancelToken none = _NeverCancelled();
}

class _NeverCancelled extends CancelToken {
  @override
  void cancel() {}
}

class CancelledException implements Exception {
  const CancelledException();

  @override
  String toString() => 'Operation cancelled';
}
