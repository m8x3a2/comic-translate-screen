/// Pages chosen by their numbers (the owner's idea): `1,5-8,10, 19-20`.
library;

/// The pages written in [text] as 0-based indexes among [count] pages.
/// Numbers and ranges are separated by commas, semicolons or spaces; a range
/// may go backwards (`8-5`). Throws [FormatException] naming the part that
/// is not a page number or is past the last page.
Set<int> parsePageNumbers(String text, int count) {
  final picked = <int>{};
  for (final part in text.split(RegExp(r'[,;\s]+'))) {
    if (part.isEmpty) continue;
    final m = RegExp(r'^(\d+)(?:[-–—](\d+))?$').firstMatch(part);
    if (m == null) throw FormatException(part);
    final a = int.parse(m[1]!), b = m[2] == null ? a : int.parse(m[2]!);
    final low = a < b ? a : b, high = a < b ? b : a;
    if (low < 1 || high > count) throw FormatException(part);
    for (var i = low; i <= high; i++) {
      picked.add(i - 1);
    }
  }
  return picked;
}

/// [indexes] (0-based) written as page numbers with ranges: `1,5-8,10`.
String pageNumbersText(Iterable<int> indexes) {
  final sorted = indexes.toSet().toList()..sort();
  final parts = <String>[];
  for (var i = 0; i < sorted.length;) {
    var j = i;
    while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
      j++;
    }
    parts.add(j == i ? '${sorted[i] + 1}' : '${sorted[i] + 1}-${sorted[j] + 1}');
    i = j + 1;
  }
  return parts.join(',');
}
