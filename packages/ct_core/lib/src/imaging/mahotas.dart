/// Ports of the mahotas/imkit operations used by the original detection code.
library;

import 'dart:typed_data';

import '../image/raster.dart';

/// `mahotas.otsu(img)` (also `imkit.otsu_threshold`, which wraps it).
///
/// mahotas builds a histogram of length `max(img) + 1` and picks the first
/// threshold maximising the between-class variance; pixels `> t` are
/// foreground.
int mahotasOtsu(Uint8List values) {
  if (values.isEmpty) return 0;
  var maxValue = 0;
  for (final v in values) {
    if (v > maxValue) maxValue = v;
  }
  final n = maxValue + 1;
  if (n <= 1) return 0;
  final hist = Float64List(n);
  for (final v in values) {
    hist[v] += 1;
  }
  var hsum = 0.0;
  for (var i = 1; i < n; i++) {
    hsum += hist[i];
  }
  if (hsum == 0) return 0;

  final nB = Float64List(n);
  nB[0] = hist[0];
  for (var i = 1; i < n; i++) {
    nB[i] = hist[i] + nB[i - 1];
  }
  final total = nB[n - 1];
  final nO = Float64List(n);
  for (var i = 0; i < n; i++) {
    nO[i] = total - nB[i];
  }

  var muB = 0.0;
  var muO = 0.0;
  for (var i = 1; i < n; i++) {
    muO += i * hist[i];
  }
  muO /= hsum;

  var best = nB[0] * nO[0] * (muB - muO) * (muB - muO);
  var bestT = 0;
  for (var t = 1; t < n; t++) {
    if (nB[t] == 0) continue;
    if (nO[t] == 0) break;
    muB = (muB * nB[t - 1] + t * hist[t]) / nB[t];
    muO = (muO * nO[t - 1] - t * hist[t]) / nO[t];
    final v = nB[t] * nO[t] * (muB - muO) * (muB - muO);
    if (v > best) {
      best = v;
      bestT = t;
    }
  }
  return bestT;
}

/// One connected component in the `cv2.connectedComponentsWithStats`
/// layout produced by `imkit.connected_components_with_stats`.
class ComponentStats {
  const ComponentStats(this.left, this.top, this.width, this.height, this.area);

  final int left;
  final int top;
  final int width;
  final int height;
  final int area;

  List<int> toList() => [left, top, width, height, area];

  @override
  String toString() => 'ComponentStats($left, $top, $width, $height, area $area)';
}

class ConnectedComponents {
  ConnectedComponents(this.width, this.height, this.count, this.labels, this.stats, this.centroids);

  final int width;
  final int height;

  /// Number of labels including the background (label 0).
  final int count;

  /// Label per pixel, row-major.
  final Int32List labels;

  /// Index = label; entry 0 is the background.
  final List<ComponentStats> stats;

  /// `(x, y)` centroid per label.
  final List<(double, double)> centroids;
}

/// `imkit.connected_components_with_stats(image, connectivity)`:
/// `mahotas.label(image > 0, Bc)` followed by mahotas size/bbox/centroid
/// statistics, reproducing imkit's arithmetic exactly (including its
/// width/height convention).
ConnectedComponents connectedComponentsWithStats(GrayImage image, {int connectivity = 4}) {
  final w = image.width, h = image.height;
  final labels = _mahotasLabel(image, connectivity);
  var numLabels = 0;
  for (final l in labels) {
    if (l > numLabels) numLabels = l;
  }

  if (numLabels == 0) {
    return ConnectedComponents(w, h, 1, labels, [ComponentStats(0, 0, w, h, w * h)], [((w - 1) / 2.0, (h - 1) / 2.0)]);
  }

  final n = numLabels + 1;
  final sizes = Int64List(n);
  final minY = Int64List(n)..fillRange(0, n, 1 << 40);
  final minX = Int64List(n)..fillRange(0, n, 1 << 40);
  final maxY = Int64List(n)..fillRange(0, n, -1);
  final maxX = Int64List(n)..fillRange(0, n, -1);
  final sumY = Int64List(n);
  final sumX = Int64List(n);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final l = labels[y * w + x];
      sizes[l]++;
      sumY[l] += y;
      sumX[l] += x;
      if (y < minY[l]) minY[l] = y;
      if (x < minX[l]) minX[l] = x;
      if (y > maxY[l]) maxY[l] = y;
      if (x > maxX[l]) maxX[l] = x;
    }
  }

  final stats = <ComponentStats>[];
  final centroids = <(double, double)>[];
  for (var l = 0; l < n; l++) {
    if (sizes[l] == 0) {
      // mahotas reports [0, 0, 0, 0]; imkit forces width/height to 0.
      stats.add(const ComponentStats(0, 0, 0, 0, 0));
      centroids.add((0.0, 0.0));
      continue;
    }
    // mahotas.labeled.bbox gives exclusive maxima; imkit then computes
    // width = xmax - xmin + 1, i.e. one more than the true extent.
    final width = (maxX[l] + 1) - minX[l] + 1;
    final height = (maxY[l] + 1) - minY[l] + 1;
    stats.add(ComponentStats(minX[l], minY[l], width, height, sizes[l]));
    centroids.add((sumX[l] / sizes[l], sumY[l] / sizes[l]));
  }
  return ConnectedComponents(w, h, n, labels, stats, centroids);
}

/// `mahotas.label(image > 0, Bc)`: labels numbered in raster order of their
/// first pixel.
Int32List _mahotasLabel(GrayImage image, int connectivity) {
  final w = image.width, h = image.height;
  final data = image.data;
  final parent = Int32List(w * h + 1);
  final provisional = Int32List(w * h);
  var next = 1;

  int find(int x) {
    while (parent[x] != x) {
      parent[x] = parent[parent[x]];
      x = parent[x];
    }
    return x;
  }

  void union(int a, int b) {
    final ra = find(a), rb = find(b);
    if (ra == rb) return;
    if (ra < rb) {
      parent[rb] = ra;
    } else {
      parent[ra] = rb;
    }
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      if (data[i] == 0) continue;
      var label = 0;
      void consider(int nx, int ny) {
        if (nx < 0 || ny < 0 || nx >= w) return;
        final ni = ny * w + nx;
        final nl = provisional[ni];
        if (nl == 0) return;
        if (label == 0) {
          label = nl;
        } else {
          union(label, nl);
        }
      }

      consider(x - 1, y);
      consider(x, y - 1);
      if (connectivity == 8) {
        consider(x - 1, y - 1);
        consider(x + 1, y - 1);
      }
      if (label == 0) {
        label = next;
        parent[next] = next;
        next++;
      }
      provisional[i] = label;
    }
  }

  final remap = Int32List(next);
  var counter = 0;
  final out = Int32List(w * h);
  for (var i = 0; i < w * h; i++) {
    final p = provisional[i];
    if (p == 0) continue;
    final root = find(p);
    if (remap[root] == 0) remap[root] = ++counter;
    out[i] = remap[root];
  }
  return out;
}
