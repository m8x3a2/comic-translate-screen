/// Opening comics: image files, folders and archives become page images on
/// disk, in reading order. Port of `modules/utils/archives.py`: zip, cbz and
/// epub (every image inside, by entry name), tar and cbt, and — through an
/// installed 7-Zip or WinRAR, as in the original — rar, cbr, 7z and cb7.
/// PDF pages are rendered by the app.
library;

import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../cancel.dart';

const imageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.bmp'};
const zipExtensions = {'.zip', '.cbz', '.epub'};
const tarExtensions = {'.tar', '.cbt'};
const rarExtensions = {'.rar', '.cbr'};
const sevenZipExtensions = {'.7z', '.cb7'};
const archiveExtensions = {...zipExtensions, ...tarExtensions, ...rarExtensions, ...sevenZipExtensions};
const pdfExtensions = {'.pdf'};

String _ext(String path) => p.extension(path).toLowerCase();

bool isImagePath(String path) => imageExtensions.contains(_ext(path));
bool isArchivePath(String path) => archiveExtensions.contains(_ext(path));
bool isPdfPath(String path) => pdfExtensions.contains(_ext(path));

/// Anything [importPages] opens.
bool isImportablePath(String path) => isImagePath(path) || isArchivePath(path) || isPdfPath(path);

final _chunks = RegExp(r'\d+|\D+');

/// Compares strings treating digit runs as numbers, case-insensitively
/// (original `natural_sort_key`), so page2 comes before page10.
int naturalCompare(String a, String b) {
  final ca = _chunks.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
  final cb = _chunks.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
  for (var i = 0; i < ca.length && i < cb.length; i++) {
    final na = int.tryParse(ca[i]), nb = int.tryParse(cb[i]);
    final c = na != null && nb != null ? na.compareTo(nb) : ca[i].compareTo(cb[i]);
    if (c != 0) return c;
  }
  return ca.length.compareTo(cb.length);
}

/// The images of folder [dir] (not recursive), in natural order.
List<String> imagesInFolder(String dir) => Directory(dir)
    .listSync()
    .whereType<File>()
    .map((f) => f.path)
    .where(isImagePath)
    .toList()
  ..sort((a, b) => naturalCompare(p.basename(a), p.basename(b)));

/// One page image on disk.
class ImportedPage {
  const ImportedPage({required this.path, required this.name, this.source});

  /// The image file (inside the import cache for archives and PDFs).
  final String path;

  /// Shown in the page list: the file or archive entry name.
  final String name;

  /// The archive or PDF the page came from, if any.
  final String? source;
}

/// A rar or 7z archive was opened without 7-Zip (or WinRAR) installed.
class ArchiveToolMissingException implements Exception {
  ArchiveToolMissingException(this.archive);

  final String archive;

  @override
  String toString() => 'Opening ${p.basename(archive)} needs 7-Zip (7-zip.org) or WinRAR installed.';
}

class PageImportException implements Exception {
  PageImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Renders the pages of a PDF into [outDir]; supplied by the app.
typedef PdfRasterizer = Future<List<ImportedPage>> Function(String pdf, Directory outDir, CancelToken cancel);

/// Turns [inputs] (images, folders, archives, PDFs) into page images.
/// Archives and PDFs are unpacked into numbered folders under [cacheDir].
/// Unsupported files are skipped and listed in [skipped]. With [onError],
/// an archive or PDF that cannot be opened is reported there and the others
/// are still imported; without it the error is thrown.
Future<List<ImportedPage>> importPages(
  List<String> inputs, {
  required Directory cacheDir,
  PdfRasterizer? pdf,
  CancelToken? cancel,
  List<String>? skipped,
  void Function(String input, Object error)? onError,
}) async {
  final token = cancel ?? CancelToken.none;
  final pages = <ImportedPage>[];
  var unpacked = 0;
  Future<Directory> nextDir(String source) async {
    Directory dir;
    do {
      dir = Directory(p.join(cacheDir.path, '${unpacked++}_${_safeName(p.basenameWithoutExtension(source))}'));
    } while (dir.existsSync());
    return dir.create(recursive: true);
  }

  for (final input in inputs) {
    token.throwIfCancelled();
    if (FileSystemEntity.isDirectorySync(input)) {
      pages.addAll([for (final f in imagesInFolder(input)) ImportedPage(path: f, name: p.basename(f))]);
    } else if (isImagePath(input)) {
      pages.add(ImportedPage(path: input, name: p.basename(input)));
    } else if (isArchivePath(input) || (isPdfPath(input) && pdf != null)) {
      try {
        final dir = await nextDir(input);
        final found = isPdfPath(input) ? await pdf!(input, dir, token) : await extractArchiveImages(input, dir, cancel: token);
        if (found.isEmpty) throw PageImportException('No pages found in ${p.basename(input)}.');
        pages.addAll(found);
      } on CancelledException {
        rethrow;
      } catch (e) {
        if (onError == null) rethrow;
        onError(input, e);
      }
    } else {
      skipped?.add(input);
    }
  }
  return pages;
}

String _safeName(String name) {
  final s = name.replaceAll(RegExp(r'[^\w\-. ]', unicode: true), '_').trim();
  return s.isEmpty ? 'archive' : (s.length > 40 ? s.substring(0, 40) : s);
}

/// Extracts the images of archive [path] into [outDir] as `001.jpg`,
/// `002.png` … in natural order of their entry names (original
/// `extract_archive`).
Future<List<ImportedPage>> extractArchiveImages(String path, Directory outDir, {CancelToken? cancel}) async {
  final token = cancel ?? CancelToken.none;
  final ext = _ext(path);
  await outDir.create(recursive: true);
  if (zipExtensions.contains(ext) || tarExtensions.contains(ext)) return _extractWithDart(path, outDir, token);
  return _extractWithTool(path, outDir, token);
}

String _numbered(int index, int count, String ext) => '${(index + 1).toString().padLeft(count.toString().length.clamp(3, 9), '0')}$ext';

Future<List<ImportedPage>> _extractWithDart(String path, Directory outDir, CancelToken token) async {
  final input = InputFileStream(path);
  try {
    final Archive archive;
    try {
      archive = zipExtensions.contains(_ext(path)) ? ZipDecoder().decodeStream(input) : TarDecoder().decodeStream(input);
    } catch (e) {
      throw PageImportException('${p.basename(path)} is not a readable ${_ext(path).substring(1)} archive: $e');
    }
    final entries = archive.files.where((f) => f.isFile && isImagePath(f.name) && !_isJunk(f.name)).toList()
      ..sort((a, b) => naturalCompare(a.name, b.name));
    final pages = <ImportedPage>[];
    for (final (i, entry) in entries.indexed) {
      token.throwIfCancelled();
      final target = p.join(outDir.path, _numbered(i, entries.length, _ext(entry.name)));
      final out = OutputFileStream(target);
      try {
        entry.writeContent(out);
      } finally {
        await out.close();
      }
      pages.add(ImportedPage(path: target, name: p.basename(entry.name), source: path));
    }
    return pages;
  } finally {
    await input.close();
  }
}

/// macOS resource forks and thumbnails that archives often carry.
bool _isJunk(String name) => name.startsWith('__MACOSX/') || p.basename(name).startsWith('._');

/// 7-Zip, then (for rar) WinRAR's UnRAR, from PATH or the usual folders.
String? findArchiveTool(String archive) {
  final candidates = <String>[
    '7z.exe',
    r'C:\Program Files\7-Zip\7z.exe',
    r'C:\Program Files (x86)\7-Zip\7z.exe',
    if (rarExtensions.contains(_ext(archive))) ...[
      'UnRAR.exe',
      r'C:\Program Files\WinRAR\UnRAR.exe',
      r'C:\Program Files (x86)\WinRAR\UnRAR.exe',
    ],
  ];
  final pathDirs = (Platform.environment['PATH'] ?? '').split(Platform.isWindows ? ';' : ':');
  for (final c in candidates) {
    if (p.isAbsolute(c)) {
      if (File(c).existsSync()) return c;
    } else {
      for (final d in pathDirs) {
        if (d.isNotEmpty && File(p.join(d, c)).existsSync()) return p.join(d, c);
      }
    }
  }
  return null;
}

Future<List<ImportedPage>> _extractWithTool(String path, Directory outDir, CancelToken token) async {
  final tool = findArchiveTool(path);
  if (tool == null) throw ArchiveToolMissingException(path);
  final tmp = Directory(p.join(outDir.path, '_unpack'));
  await tmp.create(recursive: true);
  try {
    final isUnrar = p.basename(tool).toLowerCase().startsWith('unrar');
    final args = isUnrar ? ['x', '-y', '-idq', path, '${tmp.path}${Platform.pathSeparator}'] : ['x', '-y', '-bd', '-o${tmp.path}', path];
    final process = await Process.start(tool, args);
    token.onCancel(process.kill);
    final stderrText = process.stderr.transform(const SystemEncoding().decoder).join();
    await process.stdout.drain<void>();
    final code = await process.exitCode;
    token.throwIfCancelled();
    if (code != 0) throw PageImportException('${p.basename(tool)} could not unpack ${p.basename(path)} (code $code): ${(await stderrText).trim()}');
    final files = tmp
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => isImagePath(f.path) && !_isJunk(p.relative(f.path, from: tmp.path).replaceAll(r'\', '/')))
        .toList()
      ..sort((a, b) => naturalCompare(p.relative(a.path, from: tmp.path), p.relative(b.path, from: tmp.path)));
    final pages = <ImportedPage>[];
    for (final (i, f) in files.indexed) {
      final target = p.join(outDir.path, _numbered(i, files.length, _ext(f.path)));
      await f.rename(target);
      pages.add(ImportedPage(path: target, name: p.basename(f.path), source: path));
    }
    return pages;
  } finally {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  }
}
