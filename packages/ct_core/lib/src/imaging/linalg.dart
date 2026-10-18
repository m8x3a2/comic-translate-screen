/// Small dense linear algebra for the ports of imkit's perspective helpers
/// (`np.linalg.solve` / `np.linalg.inv`).
///
/// LAPACK (`dgesv`) solves by LU decomposition with partial pivoting; this is
/// the same algorithm, so results agree with numpy up to rounding in the last
/// bits (OpenBLAS may order operations differently).
library;

/// Solves `A x = b` for a square [a] (row-major lists). Throws
/// [StateError] when the matrix is singular.
List<double> solveLinear(List<List<double>> a, List<double> b) {
  final n = b.length;
  final m = [for (final row in a) List<double>.of(row)];
  final x = List<double>.of(b);
  for (var j = 0; j < n; j++) {
    var p = j;
    for (var i = j + 1; i < n; i++) {
      if (m[i][j].abs() > m[p][j].abs()) p = i;
    }
    if (m[p][j] == 0) throw StateError('singular matrix');
    if (p != j) {
      final t = m[p];
      m[p] = m[j];
      m[j] = t;
      final tb = x[p];
      x[p] = x[j];
      x[j] = tb;
    }
    final r = 1 / m[j][j];
    for (var i = j + 1; i < n; i++) {
      m[i][j] *= r;
      final f = m[i][j];
      if (f == 0) continue;
      for (var k = j + 1; k < n; k++) {
        m[i][k] -= f * m[j][k];
      }
    }
  }
  // Forward substitution with the unit lower triangle.
  for (var i = 0; i < n; i++) {
    for (var k = 0; k < i; k++) {
      x[i] -= m[i][k] * x[k];
    }
  }
  // Back substitution with the upper triangle.
  for (var k = n - 1; k >= 0; k--) {
    if (x[k] != 0) {
      x[k] /= m[k][k];
      for (var i = 0; i < k; i++) {
        x[i] -= x[k] * m[i][k];
      }
    }
  }
  return x;
}

/// Inverse of a square matrix (`np.linalg.inv`).
List<List<double>> invert(List<List<double>> a) {
  final n = a.length;
  final columns = [
    for (var c = 0; c < n; c++) solveLinear(a, [for (var r = 0; r < n; r++) r == c ? 1.0 : 0.0]),
  ];
  return [
    for (var r = 0; r < n; r++) [for (var c = 0; c < n; c++) columns[c][r]],
  ];
}
