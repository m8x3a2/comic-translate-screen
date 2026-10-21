/// Project files (`.ctsproj`): every page with its boxes, text, translation,
/// style, mask strokes and images, in one SQLite file. As in the original's
/// `.ctpr` (`app/projects/project_state_v2.py`): files are stored once by
/// their SHA-256, and a save only writes the pages that changed, so saving
/// often (autosave) stays cheap. Font files used by the pages go into the
/// project too, so it opens the same on another computer.
///
/// The calls are synchronous (SQLite through FFI); the app runs them in a
/// background isolate.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../inpainting/mask_stroke.dart';
import '../model/text_block.dart';

/// One page as stored.
class ProjectPage {
  const ProjectPage({
    required this.id,
    required this.name,
    required this.image,
    this.source,
    this.cleanImage,
    this.mask,
    this.overflow,
    this.blocks = const [],
    this.strokes = const [],
    this.state = const {},
  });

  /// Stable within the project.
  final String id;

  /// File or archive entry name of the page.
  final String name;

  /// Archive or PDF the page came from.
  final String? source;

  /// The original page image (a file).
  final String image;

  /// The page with the text removed, and the generated mask (files).
  final String? cleanImage;
  final String? mask;

  /// Webtoon pages: the cleaned part of the page below that this page's
  /// blocks reach into (a transparent PNG, see `SeamPatch`).
  final String? overflow;
  final List<TextBlock> blocks;
  final List<MaskStroke> strokes;

  /// The app's other per-page values (status, enlargement, languages, ...);
  /// JSON values only.
  final Map<String, Object?> state;
}

class ProjectData {
  const ProjectData({required this.pages, this.state = const {}});

  final List<ProjectPage> pages;

  /// Project-wide values of the app (current page, ...); JSON values only.
  final Map<String, Object?> state;
}

/// What a project file holds, read without opening its pages.
class ProjectInfo {
  const ProjectInfo({required this.pages, required this.bytes, this.saved, this.appVersion});

  final int pages;
  final int bytes;
  final DateTime? saved;
  final String? appVersion;
}

class ProjectSaveReport {
  const ProjectSaveReport({required this.pagesWritten, required this.filesAdded, required this.filesRemoved});

  /// Pages that changed since the last save.
  final int pagesWritten;
  final int filesAdded;
  final int filesRemoved;
}

class ProjectFormatException implements Exception {
  const ProjectFormatException(this.message, {this.newerVersion = false});

  final String message;

  /// Made by a newer version of the program.
  final bool newerVersion;

  @override
  String toString() => 'ProjectFormatException: $message';
}

/// Font files are referenced by path in a block's style.
bool isFontFile(String? s) {
  if (s == null) return false;
  final ext = p.extension(s).toLowerCase();
  return ext == '.ttf' || ext == '.otf' || ext == '.ttc';
}

class ProjectFile {
  ProjectFile._();

  static const extension = '.ctsproj';
  static const formatVersion = 1;
  static const _app = 'comic-translate-screen';

  /// Saves [data] into [path]. An existing project there is updated: new
  /// files are added, pages that did not change are kept as they are, and
  /// files no page uses any more are removed. With [replace] (Save As over
  /// another file) the file is written anew next to it and then moved over
  /// it.
  static ProjectSaveReport save(String path, ProjectData data, {String? appVersion, bool replace = false}) {
    final target = File(path);
    target.parent.createSync(recursive: true);
    if (replace || (target.existsSync() && !_isProject(target))) {
      final tmp = File('$path.$pid.tmp');
      if (tmp.existsSync()) tmp.deleteSync();
      final report = _save(tmp.path, data, appVersion);
      if (target.existsSync()) target.deleteSync();
      tmp.renameSync(path);
      return report;
    }
    return _save(path, data, appVersion);
  }

  static ProjectSaveReport _save(String path, ProjectData data, String? appVersion) {
    final db = _open(path, create: true);
    try {
      var added = 0;
      final referenced = <String>{};

      /// The blob of [file] (hashed again only when its size or time
      /// changed).
      Map<String, Object?> blobOf(String file, String name) {
        final f = File(file);
        final stat = f.statSync();
        if (stat.type == FileSystemEntityType.notFound) throw FileSystemException('file not found', file);
        final abs = p.normalize(p.absolute(file));
        final mtime = stat.modified.microsecondsSinceEpoch;
        String? hash;
        final known = db.select('SELECT hash FROM fingerprints WHERE path = ? AND size = ? AND mtime = ?', [abs, stat.size, mtime]);
        if (known.isNotEmpty) {
          final h = known.first['hash'] as String;
          if (db.select('SELECT 1 FROM blobs WHERE hash = ?', [h]).isNotEmpty) hash = h;
        }
        if (hash == null) {
          final bytes = f.readAsBytesSync();
          hash = sha256.convert(bytes).toString();
          if (db.select('SELECT 1 FROM blobs WHERE hash = ?', [hash]).isEmpty) {
            db.execute('INSERT INTO blobs(hash, ext, size, data) VALUES(?, ?, ?, ?)', [
              hash,
              p.extension(file).toLowerCase(),
              bytes.length,
              bytes,
            ]);
            added++;
          }
          db.execute('INSERT OR REPLACE INTO fingerprints(path, size, mtime, hash) VALUES(?, ?, ?, ?)', [
            abs,
            stat.size,
            mtime,
            hash,
          ]);
        }
        referenced.add(hash);
        return {'blob': hash, 'name': name};
      }

      db.execute('BEGIN');
      try {
        final existing = {
          for (final row in db.select('SELECT id, position, json FROM pages'))
            row['id'] as String: (row['position'] as int, row['json'] as String),
        };
        var written = 0;
        for (final (position, page) in data.pages.indexed) {
          final fonts = <String, Object?>{};
          for (final b in page.blocks) {
            final font = b.style?.fontFamily;
            if (isFontFile(font) && !fonts.containsKey(font) && File(font!).existsSync()) {
              fonts[font] = blobOf(font, p.basename(font));
            }
          }
          final json = jsonEncode({
            'name': page.name,
            'source': page.source,
            'image': blobOf(page.image, p.basename(page.name)),
            'clean': page.cleanImage == null ? null : blobOf(page.cleanImage!, 'clean${p.extension(page.cleanImage!)}'),
            'mask': page.mask == null ? null : blobOf(page.mask!, 'mask${p.extension(page.mask!)}'),
            if (page.overflow != null) 'overflow': blobOf(page.overflow!, 'overflow.png'),
            'blocks': [for (final b in page.blocks) b.toJson()],
            'strokes': [for (final s in page.strokes) s.toJson()],
            'fonts': fonts,
            'state': page.state,
          });
          final old = existing.remove(page.id);
          if (old == null || old.$2 != json) {
            db.execute('INSERT OR REPLACE INTO pages(id, position, json) VALUES(?, ?, ?)', [page.id, position, json]);
            written++;
          } else if (old.$1 != position) {
            db.execute('UPDATE pages SET position = ? WHERE id = ?', [position, page.id]);
          }
        }
        for (final gone in existing.keys) {
          db.execute('DELETE FROM pages WHERE id = ?', [gone]);
        }
        db.execute('INSERT OR REPLACE INTO project(id, json) VALUES(1, ?)', [jsonEncode(data.state)]);

        var removed = 0;
        for (final row in db.select('SELECT hash FROM blobs')) {
          final hash = row['hash'] as String;
          if (!referenced.contains(hash)) {
            db.execute('DELETE FROM blobs WHERE hash = ?', [hash]);
            db.execute('DELETE FROM fingerprints WHERE hash = ?', [hash]);
            removed++;
          }
        }
        _setMeta(db, 'app', _app);
        _setMeta(db, 'format_version', '$formatVersion');
        if (appVersion != null) _setMeta(db, 'app_version', appVersion);
        _setMeta(db, 'saved', DateTime.now().toUtc().toIso8601String());
        db.execute('COMMIT');
        if (removed > 0) db.execute('PRAGMA incremental_vacuum');
        return ProjectSaveReport(pagesWritten: written, filesAdded: added, filesRemoved: removed);
      } catch (_) {
        db.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      db.close();
    }
  }

  /// Reads the project at [path]; its files are written into [filesDir]
  /// (a page's files in `pages/<id>/`, fonts in `fonts/`). A font file that
  /// is still at its old place with the same size is used from there.
  static ProjectData load(String path, Directory filesDir) {
    Database db;
    var writable = true;
    try {
      db = _open(path, writable: true);
    } on ProjectFormatException {
      // A read-only file (or folder): open it without remembering the files.
      db = _open(path);
      writable = false;
    }
    try {
      _checkVersion(db);
      final blobCache = <String, String>{};
      final unpacked = <(String, String)>[];
      String materialize(Object? ref, Directory dir) {
        final m = (ref as Map).cast<String, Object?>();
        final hash = m['blob'] as String;
        final name = _safeName(m['name'] as String? ?? hash);
        final file = File(p.join(dir.path, name));
        final cached = blobCache['$hash|${file.path}'];
        if (cached != null) return cached;
        final rows = db.select('SELECT data FROM blobs WHERE hash = ?', [hash]);
        if (rows.isEmpty) throw ProjectFormatException('the project is damaged: file $name is missing');
        dir.createSync(recursive: true);
        file.writeAsBytesSync(rows.first['data'] as Uint8List);
        unpacked.add((file.path, hash));
        return blobCache['$hash|${file.path}'] = file.path;
      }

      final pages = <ProjectPage>[];
      for (final row in db.select('SELECT id, json FROM pages ORDER BY position')) {
        final id = row['id'] as String;
        final j = (jsonDecode(row['json'] as String) as Map).cast<String, Object?>();
        final dir = Directory(p.join(filesDir.path, 'pages', _safeName(id)));
        final fonts = <String, String>{};
        for (final e in ((j['fonts'] as Map?) ?? const {}).entries) {
          final old = e.key as String;
          final ref = (e.value as Map).cast<String, Object?>();
          final rows = db.select('SELECT size FROM blobs WHERE hash = ?', [ref['blob']]);
          final oldFile = File(old);
          fonts[old] = rows.isNotEmpty && oldFile.existsSync() && oldFile.lengthSync() == rows.first['size']
              ? old
              : materialize(ref, Directory(p.join(filesDir.path, 'fonts', (ref['blob'] as String).substring(0, 12))));
        }
        final blocks = <TextBlock>[];
        for (final b in (j['blocks'] as List? ?? const [])) {
          final bj = (b as Map).cast<String, Object?>();
          final style = bj['style'];
          if (style is Map && fonts.containsKey(style['font_family'])) {
            bj['style'] = {...style.cast<String, Object?>(), 'font_family': fonts[style['font_family']]};
          }
          blocks.add(TextBlock.fromJson(bj));
        }
        pages.add(ProjectPage(
          id: id,
          name: j['name'] as String? ?? id,
          source: j['source'] as String?,
          image: materialize(j['image'], dir),
          cleanImage: j['clean'] == null ? null : materialize(j['clean'], dir),
          mask: j['mask'] == null ? null : materialize(j['mask'], dir),
          overflow: j['overflow'] == null ? null : materialize(j['overflow'], dir),
          blocks: blocks,
          strokes: [
            for (final s in (j['strokes'] as List? ?? const [])) MaskStroke.fromJson((s as Map).cast<String, Object?>()),
          ],
          state: ((j['state'] as Map?) ?? const {}).cast<String, Object?>(),
        ));
      }
      // The next save knows these files without reading them again.
      if (writable && unpacked.isNotEmpty) {
        db.execute('BEGIN');
        for (final (file, hash) in unpacked) {
          final stat = File(file).statSync();
          db.execute('INSERT OR REPLACE INTO fingerprints(path, size, mtime, hash) VALUES(?, ?, ?, ?)', [
            p.normalize(p.absolute(file)),
            stat.size,
            stat.modified.microsecondsSinceEpoch,
            hash,
          ]);
        }
        db.execute('COMMIT');
      }
      final project = db.select('SELECT json FROM project WHERE id = 1');
      final state = project.isEmpty
          ? const <String, Object?>{}
          : (jsonDecode(project.first['json'] as String) as Map).cast<String, Object?>();
      return ProjectData(pages: pages, state: state);
    } finally {
      db.close();
    }
  }

  static ProjectInfo info(String path) {
    final db = _open(path);
    try {
      _checkVersion(db);
      return ProjectInfo(
        pages: db.select('SELECT COUNT(*) AS n FROM pages').first['n'] as int,
        bytes: File(path).lengthSync(),
        saved: DateTime.tryParse(_meta(db, 'saved') ?? '')?.toLocal(),
        appVersion: _meta(db, 'app_version'),
      );
    } finally {
      db.close();
    }
  }

  static bool _isProject(File f) {
    try {
      final head = f.openSync()..setPositionSync(0);
      final bytes = head.readSync(16);
      head.closeSync();
      return utf8.decode(bytes, allowMalformed: true).startsWith('SQLite format 3');
    } on FileSystemException {
      return false;
    }
  }

  static Database _open(String path, {bool create = false, bool writable = false}) {
    if (!create) {
      final f = File(path);
      if (!f.existsSync()) throw FileSystemException('project not found', path);
      if (!_isProject(f)) throw const ProjectFormatException('not a Comic Translate Screen project');
    }
    final fresh = !File(path).existsSync();
    final Database db;
    try {
      db = sqlite3.open(
        path,
        mode: create
            ? OpenMode.readWriteCreate
            : writable
            ? OpenMode.readWrite
            : OpenMode.readOnly,
      );
    } on SqliteException catch (e) {
      throw ProjectFormatException('cannot open the project: ${e.message}');
    }
    try {
      if (fresh) db.execute('PRAGMA auto_vacuum = INCREMENTAL');
      if (create) {
        db.execute('PRAGMA journal_mode = DELETE');
        db.execute('PRAGMA synchronous = NORMAL');
        db.execute('CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        db.execute('CREATE TABLE IF NOT EXISTS project(id INTEGER PRIMARY KEY CHECK (id = 1), json TEXT NOT NULL)');
        db.execute('CREATE TABLE IF NOT EXISTS pages(id TEXT PRIMARY KEY, position INTEGER NOT NULL, json TEXT NOT NULL)');
        db.execute(
          'CREATE TABLE IF NOT EXISTS blobs(hash TEXT PRIMARY KEY, ext TEXT NOT NULL, size INTEGER NOT NULL, data BLOB NOT NULL)',
        );
        db.execute(
          'CREATE TABLE IF NOT EXISTS fingerprints(path TEXT PRIMARY KEY, size INTEGER NOT NULL, mtime INTEGER NOT NULL, hash TEXT NOT NULL)',
        );
        final app = fresh ? null : _meta(db, 'app');
        if (!fresh && app != _app) throw const ProjectFormatException('not a Comic Translate Screen project');
        if (!fresh) _checkVersion(db);
      }
      return db;
    } on SqliteException catch (e) {
      db.close();
      throw ProjectFormatException('cannot read the project: ${e.message}');
    } catch (_) {
      db.close();
      rethrow;
    }
  }

  static void _checkVersion(Database db) {
    final String? app;
    try {
      app = _meta(db, 'app');
    } on SqliteException {
      throw const ProjectFormatException('not a Comic Translate Screen project');
    }
    if (app != _app) throw const ProjectFormatException('not a Comic Translate Screen project');
    final version = int.tryParse(_meta(db, 'format_version') ?? '') ?? 0;
    if (version > formatVersion) {
      throw ProjectFormatException('the project was saved by a newer version of the program (format $version)',
          newerVersion: true);
    }
  }

  static String? _meta(Database db, String key) {
    final rows = db.select('SELECT value FROM meta WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  static void _setMeta(Database db, String key, String value) =>
      db.execute('INSERT OR REPLACE INTO meta(key, value) VALUES(?, ?)', [key, value]);

  /// A file name without folders or characters Windows refuses.
  static String _safeName(String name) {
    final base = name.split(RegExp(r'[\\/]')).last;
    final clean = base.replaceAll(RegExp(r'[<>:"|?*\x00-\x1f]'), '_').trim();
    return clean.isEmpty || clean == '.' || clean == '..' ? 'file' : clean;
  }
}
