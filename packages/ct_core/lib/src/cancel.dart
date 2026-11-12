import 'dart:async';

/// Cooperative cancellation for long-running operations (batch runs, model
/// downloads). Stages call [throwIfCancelled] between steps.
class CancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  /// How many listeners wait for a cancel (for the tests).
  int get listenerCount => _listeners.length;

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

  /// Lets other events in — among them a cancel message from another
  /// isolate, which long synchronous work would keep waiting — and throws
  /// [CancelledException] when cancelled meanwhile. Long work calls it
  /// between its parts.
  Future<void> checkpoint() async {
    await Future<void>.delayed(Duration.zero);
    throwIfCancelled();
  }

  /// Waits [duration], or less when cancelled meanwhile (then throws
  /// [CancelledException]).
  Future<void> wait(Duration duration) async {
    final done = Completer<void>();
    final timer = Timer(duration, () {
      if (!done.isCompleted) done.complete();
    });
    void stop() {
      timer.cancel();
      if (!done.isCompleted) done.complete();
    }

    onCancel(stop);
    try {
      await done.future;
    } finally {
      // Waited out: the listener goes (a long run waits many times).
      _listeners.remove(stop);
    }
    throwIfCancelled();
  }

  /// A token that is never cancelled.
  static final CancelToken none = _NeverCancelled();
}

class _NeverCancelled extends CancelToken {
  @override
  void cancel() {}

  /// Never called: not kept (this token lives as long as the program, and
  /// what a listener holds — a process, a connection — would stay with it).
  @override
  void onCancel(void Function() listener) {}
}

class CancelledException implements Exception {
  const CancelledException();

  @override
  String toString() => 'Operation cancelled';
}
