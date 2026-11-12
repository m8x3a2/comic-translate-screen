import 'dart:io';
import 'dart:typed_data';

import 'package:comic_translate/services/chat_library.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late ChatLibrary library;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cts_chat_library_');
    library = ChatLibrary(directory.path);
    await library.ready;
  });

  tearDown(() async {
    library.dispose();
    await directory.delete(recursive: true);
  });

  test('moving, pinning, renaming and sending persist in recency order', () async {
    final first = await library.addChat('One', null);
    final second = await library.addChat('Two', 'local-profile');
    await library.addFolder('Projects');
    final folder = library.folders.single.id;
    await library.move(first, folder);
    await library.edit(first, (chat) => chat.copyWith(title: 'Edited', pinned: true));
    await library.append(first, (role: 'user', text: 'Recent message', attachments: [], incomplete: false));
    await library.append(first, (role: 'assistant', text: 'Partial answer', attachments: [], incomplete: true));

    library.dispose();
    library = ChatLibrary(directory.path);
    await library.ready;
    final items = {for (final item in library.visibleThreads) item.thread.id: item};
    expect(items[first]!.folder, folder);
    expect(items[first]!.thread.title, 'Edited');
    expect(items[first]!.thread.pinned, isTrue);
    expect(items[first]!.thread.updated, greaterThan(items[second]!.thread.updated));
    expect(items[second]!.thread.profile, 'local-profile');
    expect(items[first]!.thread.messages.map((message) => message.incomplete), [false, true]);
    expect(items[first]!.thread.messages.last.text, 'Partial answer');
    await library.delete(second);
    expect(library.visibleThreads.single.thread.id, first);
  });

  test('protected chat metadata, messages and images are sealed and reopen only with the password', () async {
    await library.addFolder('Visible folder');
    final folder = library.folders.single.id;
    final id = await library.addChat('Hidden title', null, folder: folder);
    await library.append(id, (
      role: 'user',
      text: 'Hidden message',
      incomplete: false,
      attachments: [
        ChatImage(Uint8List.fromList([10, 20, 30]), 'image/png', 'hidden-picture.png'),
        ChatImage(Uint8List.fromList([40, 50]), 'image/jpeg', 'second-picture.jpg'),
      ],
    ));
    await library.protect(folder, 'test-password');
    final file = await library.file.readAsString();
    for (final value in ['Hidden title', 'Hidden message', 'hidden-picture.png', 'test-password']) {
      expect(file, isNot(contains(value)));
    }

    library.dispose();
    library = ChatLibrary(directory.path, lockAfter: const Duration(milliseconds: 50));
    await library.ready;
    expect(library.folders.single.locked, isTrue);
    expect(library.visibleThreads, isEmpty);
    await expectLater(library.unlock(folder, 'wrong-password'), throwsA(isA<SecretBoxAuthenticationError>()));
    await library.unlock(folder, 'test-password');
    final attachments = library.visibleThreads.single.thread.messages.single.attachments;
    expect(attachments.map((file) => file.bytes), [
      [10, 20, 30],
      [40, 50],
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(library.folders.single.locked, isTrue);
    expect(library.visibleThreads, isEmpty);
  });

  test('a saved message with one image from an earlier version still opens', () {
    final thread = ChatThread.fromJson({
      'id': 'legacy',
      'title': 'Legacy',
      'updated': 0,
      'pinned': false,
      'messages': [
        {
          'role': 'user',
          'text': '',
          'image': {'mime': 'image/png', 'name': 'old.png', 'bytes': 'Cg=='},
        },
      ],
    });
    expect(thread.messages.single.attachments.single.name, 'old.png');
    expect(thread.messages.single.attachments.single.bytes, [10]);
  });

  test('a stale window does not overwrite a newer library revision', () async {
    final other = ChatLibrary(directory.path);
    addTearDown(other.dispose);
    await other.ready;
    await library.addChat('Original', null);
    await expectLater(other.addChat('Concurrent', null), throwsStateError);
    expect(await library.file.readAsString(), contains('Original'));
  });
}
