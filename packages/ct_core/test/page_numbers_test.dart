import 'package:ct_core/ct_core.dart';
import 'package:test/test.dart';

void main() {
  test('numbers and ranges, any separators, backwards ranges', () {
    expect(parsePageNumbers('1,5-8,10, 11 19-20', 20), {0, 4, 5, 6, 7, 9, 10, 18, 19});
    expect(parsePageNumbers(' 8–6;2 ', 10), {1, 5, 6, 7});
    expect(parsePageNumbers('', 5), isEmpty);
  });

  test('a wrong part is named', () {
    for (final (text, part) in [('1,x', 'x'), ('3-12', '3-12'), ('0', '0'), ('2-', '2-')]) {
      expect(
        () => parsePageNumbers(text, 10),
        throwsA(isA<FormatException>().having((e) => e.message, 'message', part)),
      );
    }
  });

  test('pages written back as numbers with ranges', () {
    expect(pageNumbersText([9, 0, 4, 5, 6, 7, 10]), '1,5-8,10-11');
    expect(pageNumbersText([]), '');
    expect(parsePageNumbers(pageNumbersText({2, 3, 7}), 8), {2, 3, 7});
  });
}
