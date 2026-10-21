/// Saving the work outside the program: the translated pages (and/or the
/// cleaned pages and the texts) into a folder, or packed as ZIP, CBZ, CB7 or
/// PDF, optionally one file per chapter (original
/// `ProjectController.save_and_make` and `modules/utils/archives.py: make`).
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../image/cv_bridge.dart';
import '../import/page_import.dart';
import 'pdf_writer.dart';
import 'strip_export.dart';

enum ExportContainer {
  folder,
  zip,
  cbz,
  cb7,
  pdf;

  String get extension => '.$name';

  /// Comic reader formats: pictures of one kind, no texts.
  bool get forReaders => this == cbz || this == cb7 || this == pdf;

  static ExportContainer parse(String? name) =>
      values.firstWhere((c) => c.name == name, orElse: () => ExportContainer.folder);
}

/// One page to export.
class ExportPage {
  const ExportPage({
    required this.name,
    this.chapter = '',
    this.sourceExtension = '.png',
    this.translatedImage,
    this.cleanImage,
    this.recognized,
    this.translations,
  });

  /// File name of the page without extension (unique names are made from
  /// it).
  final String name;

  /// Pages of the same chapter go into the same file when exporting by
  /// chapter (the archive or PDF they came from).
  final String chapter;

  /// Image format of the original page, for the `source` image format.
  final String sourceExtension;

  /// The page drawn with its translation, and the page with the text
  /// removed (files).
  final String? translatedImage;
  final String? cleanImage;

  /// `block_N` → text, as the original's text exports.
  final Map<String, String>? recognized;
  final Map<String, String>? translations;
}

class ExportOptions {
  const ExportOptions({
    this.container = ExportContainer.folder,
    this.imageFormat = 'source',
    this.translated = true,
    this.cleaned = false,
    this.recognizedText = false,
    this.translatedText = false,
    this.byChapter = false,
    this.strip = StripExport.pages,
    this.sliceHeight = 1280,
    this.extraFiles = const {},
  });

  final ExportContainer container;

  /// `source`, `png`, `jpg`, `webp` (PDF: `png` keeps every pixel, any
  /// other is JPEG) or `psd`: the translated pictures are then layered
  /// Photoshop files the caller made ([ExportPage.translatedImage]), copied
  /// as they are; cleaned pages are saved as PNG.
  final String imageFormat;
  final bool translated;
  final bool cleaned;
  final bool recognizedText;
  final bool translatedText;

  /// One file (or folder) per chapter.
  final bool byChapter;

  /// Webtoons: the pages as they are, as one picture, or cut again into
  /// parts of about [sliceHeight] rows (per chapter).
  final StripExport strip;
  final int sliceHeight;

  /// Files put beside the pages of each folder or archive (not PDF): path
  /// inside it → file (fonts the PSD files use).
  final Map<String, String> extraFiles;

  ExportOptions withExtraFiles(Map<String, String> files) => ExportOptions(
    container: container,
    imageFormat: imageFormat,
    translated: translated,
    cleaned: cleaned,
    recognizedText: recognizedText,
    translatedText: translatedText,
    byChapter: byChapter,
    strip: strip,
    sliceHeight: sliceHeight,
    extraFiles: {...extraFiles, ...files},
  );
}

class ExportResult {
  const ExportResult(this.outputs, this.pages);

  /// Written files or folders.
  final List<String> outputs;

  /// Pages written (counted once even if several kinds were saved).
  final int pages;
}

class ExportException implements Exception {
  const ExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A file name without characters Windows refuses (original
/// `_sanitize_export_stem`).
String safeFileStem(String value, {String fallback = 'chapter'}) {
  final s = value.replaceAll(RegExp(r'[\\/:*?"<>|\r\n\t]+'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();
  final t = s.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
  return t.isEmpty ? fallback : t;
}

/// Exports [pages] into [output]: the file when everything goes into one
/// archive or PDF, otherwise a folder (created if missing). [bookName]
/// names the result when there are no chapters. CB7 needs 7-Zip
/// ([sevenZip]). Runs synchronously apart from 7-Zip; the app calls it in a
/// background isolate.
Future<ExportResult> exportPages(
  List<ExportPage> pages,
  ExportOptions options,
  String output, {
  String bookName = 'comic',
  String? sevenZip,
}) async {
  final o = options;
  final groups = <String, List<ExportPage>>{};
  for (final page in pages) {
    groups.putIfAbsent(o.byChapter ? page.chapter : '', () => []).add(page);
  }
  final split = groups.length > 1;
  final kinds = <String>[
    if (o.translated) 'translated',
    if (o.cleaned && !(o.container.forReaders && o.translated)) 'cleaned',
    if (!o.container.forReaders && o.recognizedText) 'raw_texts',
    if (!o.container.forReaders && o.translatedText) 'translated_texts',
  ];
  if (kinds.isEmpty) throw const ExportException('nothing to export');
  final psd = o.imageFormat == 'psd';
  if (psd && o.container.forReaders) throw const ExportException('PSD files go into a folder or a ZIP');
  if (psd && o.strip != StripExport.pages) throw const ExportException('PSD files are saved page by page');
  if (o.container == ExportContainer.cb7 && sevenZip == null) throw ArchiveToolMissingException(output);

  final outputs = <String>[];
  final written = <ExportPage>{};
  final usedNames = <String>{};
  final strips = o.strip == StripExport.pages ? null : Directory.systemTemp.createTempSync('cts_strip_');
  try {
    for (final MapEntry(key: chapter, value: group) in groups.entries) {
      final title = safeFileStem(chapter.isEmpty ? bookName : chapter);
      // Webtoons joined or cut again: the pictures are new, the texts stay
      // per page.
      final pictures = strips == null
          ? group
          : await _joined(group, o, p.join(strips.path, '${groups.keys.toList().indexOf(chapter)}'), title);
      final names = _pageNames(group);
      final pictureNames = identical(pictures, group) ? names : _pageNames(pictures);
      if (o.container == ExportContainer.pdf) {
        final file = split ? p.join(output, _unique('$title.pdf', usedNames)) : output;
        Directory(p.dirname(file)).createSync(recursive: true);
        final pdf = ImagePdfWriter(file);
        try {
          for (final page in pictures) {
            final source = kinds.first == 'translated' ? page.translatedImage : page.cleanImage;
            if (source == null) continue;
            final image = await ImageCodec.readFile(source);
            if (o.imageFormat == 'png') {
              pdf.addRgb(image);
            } else {
              pdf.addJpeg(ImageCodec.encodeJpeg(image, quality: 92), image.width, image.height);
            }
            written.addAll(identical(pictures, group) ? [page] : group);
          }
        } finally {
          pdf.close();
        }
        outputs.add(file);
        continue;
      }

      final Directory dir;
      final Directory? staging;
      if (o.container == ExportContainer.folder) {
        dir = Directory(split ? p.join(output, _unique(title, usedNames)) : output);
        staging = null;
      } else {
        staging = Directory.systemTemp.createTempSync('cts_export_');
        dir = staging;
      }
      try {
        dir.createSync(recursive: true);
        for (final kind in kinds) {
          final into = kinds.length == 1 ? dir.path : p.join(dir.path, kind);
          Directory(into).createSync(recursive: true);
          final isPicture = kind == 'translated' || kind == 'cleaned';
          for (final (i, page) in (isPicture ? pictures : group).indexed) {
            final name = isPicture ? pictureNames[i] : names[i];
            switch (kind) {
              case 'translated' || 'cleaned':
                final source = kind == 'translated' ? page.translatedImage : page.cleanImage;
                if (source == null) continue;
                final ext = switch (o.imageFormat) {
                  'source' => _writable(page.sourceExtension),
                  'psd' when kind == 'cleaned' => '.png',
                  // PSB for pages too tall for PSD.
                  'psd' => p.extension(source).toLowerCase(),
                  final f => '.$f',
                };
                if (psd && kind == 'translated' && ext != '.psd' && ext != '.psb') {
                  throw ExportException('${page.name}: no PSD file made');
                }
                final target = p.join(into, '$name$ext');
                if (p.extension(source).toLowerCase() == ext) {
                  File(source).copySync(target);
                } else {
                  await ImageCodec.writeFile(target, await ImageCodec.readFile(source));
                }
                written.addAll(identical(pictures, group) ? [page] : group);
              case 'raw_texts' || 'translated_texts':
                final texts = kind == 'raw_texts' ? page.recognized : page.translations;
                if (texts == null) continue;
                final suffix = kind == 'raw_texts' ? 'raw' : 'translated';
                File(p.join(into, '${name}_$suffix.json'))
                    .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(texts));
                written.add(page);
            }
          }
        }
        for (final MapEntry(key: name, value: source) in o.extraFiles.entries) {
          final target = File(p.join(dir.path, name));
          target.parent.createSync(recursive: true);
          File(source).copySync(target.path);
        }
        if (staging == null) {
          outputs.add(dir.path);
          continue;
        }
        final file = split ? p.join(output, _unique('$title${o.container.extension}', usedNames)) : output;
        Directory(p.dirname(file)).createSync(recursive: true);
        if (File(file).existsSync()) File(file).deleteSync();
        if (o.container == ExportContainer.cb7) {
          final r = await Process.run(sevenZip!, [
            'a',
            '-t7z',
            '-mx=1',
            '-bd',
            '-y',
            file,
            '.${Platform.pathSeparator}*',
          ], workingDirectory: staging.path);
          if (r.exitCode != 0) {
            throw ExportException('7-Zip could not write ${p.basename(file)}: ${'${r.stderr}'.trim()}');
          }
        } else {
          final zip = ZipFileEncoder()..create(file);
          final streams = <InputFileStream>[];
          try {
            final files = staging.listSync(recursive: true).whereType<File>().toList()
              ..sort((a, b) => naturalCompare(a.path, b.path));
            for (final f in files) {
              // Pictures are compressed already: stored as they are.
              final stream = InputFileStream(f.path);
              streams.add(stream);
              zip.addArchiveFile(
                ArchiveFile.stream(p.relative(f.path, from: staging.path).replaceAll(r'\', '/'), stream)
                  ..compression = CompressionType.none,
              );
            }
          } finally {
            zip.closeSync();
            for (final s in streams) {
              s.closeSync();
            }
          }
        }
        outputs.add(file);
      } finally {
        if (staging != null && staging.existsSync()) staging.deleteSync(recursive: true);
      }
    }
  } finally {
    if (strips != null && strips.existsSync()) strips.deleteSync(recursive: true);
  }
  return ExportResult(outputs, written.length);
}

/// The pictures of [group] joined into one strip, or cut again (see
/// [joinStrip]), as pages named after [title]; translated and cleaned
/// pictures are cut at the same rows.
Future<List<ExportPage>> _joined(List<ExportPage> group, ExportOptions o, String dir, String title) async {
  final slice = o.strip == StripExport.slices ? o.sliceHeight.clamp(minSliceHeight, maxSliceHeight) : null;
  final translated = [for (final page in group) ?page.translatedImage];
  final cleaned = [for (final page in group) ?page.cleanImage];
  // Only when every page has the picture: a strip with holes would not fit.
  List<String>? tFiles, cFiles;
  List<int>? cuts;
  if (o.translated && translated.length == group.length) {
    (tFiles, cuts) = await joinStrip(translated, p.join(dir, 't'), title, '.png', sliceHeight: slice);
  }
  if (o.cleaned && cleaned.length == group.length) {
    (cFiles, _) = await joinStrip(
      cleaned,
      p.join(dir, 'c'),
      title,
      '.png',
      sliceHeight: slice,
      cuts: slice == null || cuts == null ? null : cuts,
    );
  }
  final n = math.max(tFiles?.length ?? 0, cFiles?.length ?? 0);
  return [
    for (var i = 0; i < n; i++)
      ExportPage(
        name: p.basenameWithoutExtension((tFiles ?? cFiles)![i]),
        chapter: group.first.chapter,
        sourceExtension: group.first.sourceExtension,
        translatedImage: tFiles != null && i < tFiles.length ? tFiles[i] : null,
        cleanImage: cFiles != null && i < cFiles.length ? cFiles[i] : null,
      ),
  ];
}

/// Unique file names for the pages, in their order: readers sort pages by
/// name, so when the names would sort differently, they get a number first.
List<String> _pageNames(List<ExportPage> pages) {
  final used = <String>{};
  final names = [for (final page in pages) _unique(safeFileStem(page.name, fallback: 'page'), used, lower: true)];
  final sorted = [...names]..sort(naturalCompare);
  var inOrder = true;
  for (var i = 0; i < names.length; i++) {
    if (sorted[i] != names[i]) inOrder = false;
  }
  if (inOrder) return names;
  final width = '${names.length}'.length.clamp(3, 6);
  return [for (final (i, n) in names.indexed) '${'${i + 1}'.padLeft(width, '0')}_$n'];
}

String _unique(String name, Set<String> used, {bool lower = true}) {
  final ext = p.extension(name);
  final stem = ext.isEmpty ? name : name.substring(0, name.length - ext.length);
  var candidate = name;
  for (var n = 2; !used.add(lower ? candidate.toLowerCase() : candidate); n++) {
    candidate = '${stem}_${n.toString().padLeft(2, '0')}$ext';
  }
  return candidate;
}

/// [ext] if pictures can be written in it, else `.png`.
String _writable(String ext) {
  final e = ext.toLowerCase();
  return const {'.png', '.jpg', '.jpeg', '.webp', '.bmp'}.contains(e) ? e : '.png';
}
