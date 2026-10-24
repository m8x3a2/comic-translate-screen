/// Python/numpy numeric semantics needed for exact ports of the original code.
library;

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:typed_data';

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

/// Counts of byte values (0..255): [npMedian] and [npPercentile] of many
/// pixels without sorting them, with the same results.
class ByteHistogram {
  final counts = Int32List(256);
  int length = 0;

  void add(int v) {
    counts[v]++;
    length++;
  }

  /// The [k]-th smallest value (0-based).
  int nth(int k) {
    var seen = 0;
    for (var v = 0; v < 256; v++) {
      seen += counts[v];
      if (seen > k) return v;
    }
    throw RangeError.range(k, 0, length - 1);
  }

  double median() {
    if (length == 0) throw ArgumentError('median of an empty list');
    final mid = length ~/ 2;
    if (length.isOdd) return nth(mid).toDouble();
    return (nth(mid - 1).toDouble() + nth(mid).toDouble()) / 2;
  }

  double percentile(num q) {
    if (length == 0) throw ArgumentError('percentile of an empty list');
    if (length == 1) return nth(0).toDouble();
    final pos = (length - 1) * q.toDouble() / 100.0;
    final lo = pos.floor();
    final hi = math.min(lo + 1, length - 1);
    final frac = pos - lo;
    final a = nth(lo).toDouble(), b = nth(hi).toDouble();
    final diff = b - a;
    return frac >= 0.5 ? b - diff * (1 - frac) : a + diff * frac;
  }
}

/// `numpy.sum` of float64 values, with numpy's summation order: pairwise
/// summation inside buffers of 8192 elements, buffers added in sequence.
double npSum(Iterable<num> values) {
  final a = Float64List.fromList([for (final v in values) v.toDouble()]);
  var res = 0.0;
  for (var start = 0; start < a.length; start += 8192) {
    res += _pairwiseSum(a, start, math.min(8192, a.length - start));
  }
  return res;
}

// numpy/_core/src/umath/loops_utils.h.src: pairwise_sum.
double _pairwiseSum(Float64List a, int start, int n) {
  if (n < 8) {
    var res = -0.0;
    for (var i = 0; i < n; i++) {
      res += a[start + i];
    }
    return res;
  }
  if (n <= 128) {
    final r = Float64List.sublistView(a, start, start + 8).toList();
    var i = 8;
    for (; i < n - (n % 8); i += 8) {
      for (var j = 0; j < 8; j++) {
        r[j] += a[start + i + j];
      }
    }
    var res = ((r[0] + r[1]) + (r[2] + r[3])) + ((r[4] + r[5]) + (r[6] + r[7]));
    for (; i < n; i++) {
      res += a[start + i];
    }
    return res;
  }
  var n2 = n ~/ 2;
  n2 -= n2 % 8;
  return _pairwiseSum(a, start, n2) + _pairwiseSum(a, start + n2, n - n2);
}

/// `numpy.mean`.
double npMean(Iterable<num> values) {
  final list = values.toList();
  if (list.isEmpty) throw ArgumentError('mean of an empty list');
  return npSum(list) / list.length;
}

/// `numpy.std` (population, `ddof=0`).
double npStd(Iterable<num> values) {
  final list = [for (final v in values) v.toDouble()];
  final mean = npMean(list);
  return math.sqrt(npSum([for (final v in list) (v - mean) * (v - mean)]) / list.length);
}

/// `numpy.corrcoef(x, y)[0, 1]`. numpy multiplies the centred vectors with
/// BLAS, whose summation order is unspecified, so this can differ from numpy
/// in the last bits; callers only compare it against coarse thresholds.
double npCorrcoef(List<num> x, List<num> y) {
  final n = x.length;
  final mx = npMean(x), my = npMean(y);
  var sxx = 0.0, syy = 0.0, sxy = 0.0;
  for (var i = 0; i < n; i++) {
    final dx = x[i] - mx, dy = y[i] - my;
    sxx += dx * dx;
    syy += dy * dy;
    sxy += dx * dy;
  }
  final f = 1 / (n - 1);
  final r = sxy * f / math.sqrt(sxx * f) / math.sqrt(syy * f);
  return r.clamp(-1.0, 1.0);
}

/// Python's `math.tanh`: the C runtime's `tanh`, which Dart's `dart:math`
/// lacks. Falls back to a Dart formula where the C function is unavailable.
double pyTanh(double x) => (_cTanh ??= _loadCTanh())(x);

double Function(double)? _cTanh;

double Function(double) _loadCTanh() {
  try {
    final lib = Platform.isWindows ? ffi.DynamicLibrary.open('ucrtbase.dll') : ffi.DynamicLibrary.process();
    return lib.lookupFunction<ffi.Double Function(ffi.Double), double Function(double)>('tanh');
  } catch (_) {
    return (x) {
      if (x > 20) return 1.0;
      if (x < -20) return -1.0;
      final e = math.exp(2 * x);
      return (e - 1) / (e + 1);
    };
  }
}
