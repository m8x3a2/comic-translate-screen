/// Pages added again (the owner's idea): files with the same bytes as a page
/// already open, or as an earlier file of the same adding.
library;

import 'dart:io';

import 'package:crypto/crypto.dart';

/// For each of [added], the index in `[...existing, ...added]` of the first
/// file before it with the same bytes, or null. Sizes are compared first, so
/// only files of the same size are read. Missing files repeat nothing.
Future<List<int?>> findRepeatedFiles(List<String> existing, List<String> added) async {
  final all = [...existing, ...added];
  final sizes = [for (final path in all) await File(path).length().then<int?>((n) => n, onError: (_) => null)];
  final bySize = <int, List<int>>{};
  for (final (i, size) in sizes.indexed) {
    if (size != null) bySize.putIfAbsent(size, () => []).add(i);
  }
  final repeats = List<int?>.filled(added.length, null);
  for (final group in bySize.values) {
    if (group.length < 2 || group.last < existing.length) continue;
    final firstOf = <Digest, int>{};
    for (final i in group) {
      final Digest digest;
      try {
        digest = md5.convert(await File(all[i]).readAsBytes());
      } on FileSystemException {
        continue;
      }
      final first = firstOf.putIfAbsent(digest, () => i);
      if (first != i && i >= existing.length) repeats[i - existing.length] = first;
    }
  }
  return repeats;
}
