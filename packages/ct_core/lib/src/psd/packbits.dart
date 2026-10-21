/// PackBits, the run-length compression of PSD channel rows.
library;

import 'dart:typed_data';

/// Packs [src] from [start] to [end] into [out] at [at]; returns the new
/// end in [out] ([out] needs `n + n / 128 + 1` free bytes).
int packBits(Uint8List src, int start, int end, Uint8List out, int at) {
  var i = start;
  var o = at;
  while (i < end) {
    // A run of 3 or more equal bytes.
    var run = 1;
    while (i + run < end && run < 128 && src[i + run] == src[i]) {
      run++;
    }
    if (run >= 3 || (run == 2 && i + run == end)) {
      out[o++] = 257 - run;
      out[o++] = src[i];
      i += run;
      continue;
    }
    // Literal bytes until the next run of 3.
    final from = i;
    while (i < end && i - from < 128) {
      if (i + 2 < end && src[i] == src[i + 1] && src[i] == src[i + 2]) break;
      i++;
    }
    out[o++] = i - from - 1;
    out.setRange(o, o + i - from, src, from);
    o += i - from;
  }
  return o;
}

/// Unpacks [src] from [start] (packed length [packed]) into [out] from [at]
/// up to [count] bytes; returns the bytes written.
int unpackBits(Uint8List src, int start, int packed, Uint8List out, int at, int count) {
  var i = start;
  final end = start + packed;
  var o = at;
  final limit = at + count;
  while (i < end && o < limit) {
    final n = src[i++];
    if (n < 128) {
      final len = n + 1;
      final take = (limit - o).clamp(0, len);
      if (i + take > src.length) break;
      out.setRange(o, o + take, src, i);
      o += take;
      i += len;
    } else if (n > 128) {
      if (i >= src.length) break;
      final len = 257 - n;
      final v = src[i++];
      final take = (limit - o).clamp(0, len);
      out.fillRange(o, o + take, v);
      o += take;
    }
    // 128: no-op.
  }
  return o - at;
}
