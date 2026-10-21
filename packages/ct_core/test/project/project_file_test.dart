import 'dart:convert';
import 'dart:io';

import 'package:ct_core/ct_core.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cts_project_test_'));
  tearDown(() => dir.deleteSync(recursive: true));

  String file(String name, List<int> bytes) {
    final f = File(p.join(dir.path, 'src', name))..parent.createSync(recursive: true);
    f.writeAsBytesSync(bytes);
    return f.path;
  }

  TextBlock block(String text, {String? font}) => TextBlock(
        xyxy: const BBox(10, 20, 110, 80),
        text: text,
        translation: '[ru] $text',
        style: font == null ? null : BlockStyle(fontFamily: font, bold: true),
      );

  ProjectData chapter({String translation = 'Hello'}) {
    final font = file('Lettering.ttf', List.filled(300, 7));
    return ProjectData(
      pages: [
        ProjectPage(
          id: 'a',
          name: 'chapter/001.png',
          source: 'chapter.cbz',
          image: file('001.png', [1, 2, 3, 4]),
          cleanImage: file('a_clean.png', [5, 6, 7]),
          mask: file('a_mask.png', [8, 9]),
          blocks: [block(translation, font: font), block('Bye')],
          strokes: const [
            MaskStroke(points: [Point2(1, 2), Point2(3, 4)], width: 12),
            MaskStroke(points: [Point2(5, 6)], width: 4, erase: true),
          ],
          state: const {'status': 'done', 'render_scale': 1.5},
        ),
        // The same picture twice: stored once.
        ProjectPage(id: 'b', name: '002.png', image: file('002.png', [1, 2, 3, 4])),
      ],
      state: const {'current': 1},
    );
  }

  test('a project keeps pages, boxes, styles, strokes and files, and fonts', () {
    final path = p.join(dir.path, 'My chapter.ctsproj');
    final first = ProjectFile.save(path, chapter(), appVersion: '0.1.0');
    expect((first.pagesWritten, first.filesAdded), (2, 4), reason: 'image, clean, mask, font; the copy is not stored again');

    final info = ProjectFile.info(path);
    expect((info.pages, info.appVersion), (2, '0.1.0'));
    expect(info.saved, isNotNull);

    final data = ProjectFile.load(path, Directory(p.join(dir.path, 'open')));
    expect(data.state, {'current': 1});
    final a = data.pages.first;
    expect((a.id, a.name, a.source), ('a', 'chapter/001.png', 'chapter.cbz'));
    expect(p.basename(a.image), '001.png');
    expect(File(a.image).readAsBytesSync(), [1, 2, 3, 4]);
    expect(File(a.cleanImage!).readAsBytesSync(), [5, 6, 7]);
    expect(File(a.mask!).readAsBytesSync(), [8, 9]);
    expect(a.strokes.map((s) => s.toJson()), chapter().pages.first.strokes.map((s) => s.toJson()));
    expect(a.state, {'status': 'done', 'render_scale': 1.5});
    expect(a.blocks.map((b) => b.toJson()), chapter().pages.first.blocks.map((b) => b.toJson()),
        reason: 'the font file is still where it was, so its path stays');
    expect(File(data.pages.last.image).readAsBytesSync(), [1, 2, 3, 4]);

    // On another computer the font comes out of the project.
    File(p.join(dir.path, 'src', 'Lettering.ttf')).deleteSync();
    final moved = ProjectFile.load(path, Directory(p.join(dir.path, 'elsewhere')));
    final font = moved.pages.first.blocks.first.style!.fontFamily!;
    expect(p.isWithin(p.join(dir.path, 'elsewhere', 'fonts'), font), isTrue);
    expect(File(font).lengthSync(), 300);
  });

  test('a webtoon page keeps the cleaned part of the page below it', () {
    final path = p.join(dir.path, 'w.ctsproj');
    ProjectFile.save(
      path,
      ProjectData(
        pages: [
          ProjectPage(id: 'a', name: '1.png', image: file('1.png', [1]), overflow: file('ov.png', [4, 2])),
          ProjectPage(id: 'b', name: '2.png', image: file('2.png', [2])),
        ],
        state: const {'current': 0, 'webtoon': true},
      ),
    );
    final back = ProjectFile.load(path, Directory(p.join(dir.path, 'open')));
    expect(back.state['webtoon'], isTrue);
    expect(File(back.pages.first.overflow!).readAsBytesSync(), [4, 2]);
    expect(back.pages.last.overflow, isNull);
  });

  test('saving again writes only what changed and drops unused files', () {
    final path = p.join(dir.path, 'c.ctsproj');
    ProjectFile.save(path, chapter());
    final same = ProjectFile.save(path, chapter());
    expect((same.pagesWritten, same.filesAdded, same.filesRemoved), (0, 0, 0));

    final edited = ProjectFile.save(path, chapter(translation: 'Hi'));
    expect((edited.pagesWritten, edited.filesAdded), (1, 0));

    // Page "a" goes: its clean page, mask and font are not needed any more.
    final only = chapter();
    final removed = ProjectFile.save(path, ProjectData(pages: [only.pages.last]));
    expect(removed.filesRemoved, 3);
    final back = ProjectFile.load(path, Directory(p.join(dir.path, 'open')));
    expect(back.pages.map((x) => x.id), ['b']);

    // After opening, the files are known: nothing is read or written again.
    final reopened = ProjectFile.save(path, back);
    expect((reopened.pagesWritten, reopened.filesAdded, reopened.filesRemoved), (0, 0, 0));
  });

  test('page order is kept; Save As replaces another file', () {
    final path = p.join(dir.path, 'order.ctsproj');
    final data = chapter();
    ProjectFile.save(path, ProjectData(pages: data.pages.reversed.toList()));
    expect(ProjectFile.load(path, Directory(p.join(dir.path, 'o1'))).pages.map((x) => x.id), ['b', 'a']);

    final other = File(p.join(dir.path, 'notes.ctsproj'))..writeAsStringSync('not a project');
    ProjectFile.save(other.path, data);
    expect(ProjectFile.info(other.path).pages, 2);
    ProjectFile.save(other.path, ProjectData(pages: [data.pages.last]), replace: true);
    expect(ProjectFile.info(other.path).pages, 1);
  });

  test('other files and newer versions are refused with a clear reason', () {
    final text = File(p.join(dir.path, 'x.ctsproj'))..writeAsStringSync('hello');
    expect(() => ProjectFile.load(text.path, dir), throwsA(isA<ProjectFormatException>()));
    expect(() => ProjectFile.info(p.join(dir.path, 'missing.ctsproj')), throwsA(isA<FileSystemException>()));

    final other = p.join(dir.path, 'other.db');
    sqlite3.open(other)
      ..execute('CREATE TABLE t(x)')
      ..close();
    expect(() => ProjectFile.load(other, dir), throwsA(isA<ProjectFormatException>()));

    final path = p.join(dir.path, 'new.ctsproj');
    ProjectFile.save(path, chapter());
    sqlite3.open(path)
      ..execute("UPDATE meta SET value = '99' WHERE key = 'format_version'")
      ..close();
    expect(
      () => ProjectFile.load(path, dir),
      throwsA(isA<ProjectFormatException>().having((e) => e.newerVersion, 'newer', isTrue)),
    );
    expect(jsonEncode(const ProjectFormatException('x').toString()), contains('x'));
  });
}
