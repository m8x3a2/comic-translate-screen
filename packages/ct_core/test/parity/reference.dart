import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

/// Repository root (tests run with the package directory as cwd).
final repoRoot = p.normalize(p.join(Directory.current.path, '..', '..'));

/// Loads `test_data/reference/<name>`.
Map<String, Object?> loadReference(String name) =>
    (jsonDecode(File(p.join(repoRoot, 'test_data', 'reference', name)).readAsStringSync()) as Map)
        .cast<String, Object?>();

Uint8List b64Bytes(Object? value) => base64Decode(value as String);

Int32List b64Int32(Object? value) {
  final bytes = base64Decode(value as String);
  return bytes.buffer.asInt32List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
}

String pagePath(String name) => p.join(repoRoot, 'test_data', 'pages', 'peppercarrot', '$name.jpg');
