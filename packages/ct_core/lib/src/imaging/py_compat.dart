/// Python/numpy numeric semantics needed for exact ports of the original code.
library;

import 'dart:math' as math;

/// Python's `round(x)` / `numpy.rint`: round half to even (2.5 → 2, 3.5 → 4).
/// Dart's `round()` rounds half away from zero, which shifts boxes by a pixel.
int pyRound(num x) {
  final d = x.toDouble();
  final floor = d.floorToDouble();
  final diff = d - floor;
  if (diff > 0.5) return floor.toInt() + 1;
  if (diff < 0.5) return floor.toInt();
  final f = floor.toInt();
  return f.isEven ? f : f + 1;
}

/// `numpy.rint` (half to even), as a double.
double npRint(num x) => pyRound(x).toDouble();

/// `numpy.median` of a non-empty list: the middle element, or the mean of
/// the two middle elements (not an interpolation, which rounds differently).
double npMedian(Iterable<num> values) {
  final sorted = values.map((v) => v.toDouble()).toList()..sort();
  if (sorted.isEmpty) throw ArgumentError('median of an empty list');
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) return sorted[mid];
  return (sorted[mid - 1] + sorted[mid]) / 2;
}

/// `numpy.percentile(values, q)` with the default linear interpolation.
double npPercentile(Iterable<num> values, num q) {
  final sorted = values.map((v) => v.toDouble()).toList()..sort();
  if (sorted.isEmpty) throw ArgumentError('percentile of an empty list');
  if (sorted.length == 1) return sorted.first;
  final pos = (sorted.length - 1) * q.toDouble() / 100.0;
  final lo = pos.floor();
  final hi = math.min(lo + 1, sorted.length - 1);
  final frac = pos - lo;
  // numpy's _lerp: a + (b - a) * t, with the symmetric form for t >= 0.5.
  final a = sorted[lo], b = sorted[hi];
  final diff = b - a;
  return frac >= 0.5 ? b - diff * (1 - frac) : a + diff * frac;
}

/// `numpy.mean`.
double npMean(Iterable<num> values) {
  var sum = 0.0;
  var n = 0;
  for (final v in values) {
    sum += v;
    n++;
  }
  if (n == 0) throw ArgumentError('mean of an empty list');
  return sum / n;
}
