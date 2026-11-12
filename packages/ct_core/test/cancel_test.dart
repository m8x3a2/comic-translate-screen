import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  // Every finished wait and every archive or download left its listener in
  // the token for good (with the process or connection it held).
  test('a finished wait leaves no listener; the token never cancelled keeps none', () async {
    final token = CancelToken();
    for (var i = 0; i < 5; i++) {
      await token.wait(Duration.zero);
    }
    expect(token.listenerCount, 0);

    CancelToken.none.onCancel(() => fail('never cancelled'));
    await CancelToken.none.wait(Duration.zero);
    expect(CancelToken.none.listenerCount, 0);
  });

  test('a wait cancelled meanwhile ends at once with a cancel', () async {
    final token = CancelToken();
    final waiting = token.wait(const Duration(minutes: 1));
    token.cancel();
    await expectLater(waiting, throwsA(isA<CancelledException>()));
    expect(token.listenerCount, 0);
    var called = false;
    token.onCancel(() => called = true);
    expect(called, isTrue, reason: 'already cancelled: at once');
  });
}
