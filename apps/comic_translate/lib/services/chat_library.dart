import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:path/path.dart' as p;

class ChatImage {
  ChatImage(this.bytes, this.mime, this.name);

  final Uint8List bytes;
  final String mime;
  final String name;
  bool get isImage => mime.startsWith('image/');
  late final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

  Map<String, String> toJson() => {'mime': mime, 'name': name, 'bytes': base64Encode(bytes)};

  factory ChatImage.fromJson(Map json) =>
      ChatImage(base64Decode(json['bytes'] as String), json['mime'] as String, json['name'] as String);
}

typedef ChatMessage = ({String role, String text, List<ChatImage> attachments, bool incomplete});

class ChatThread {
  const ChatThread(this.id, this.title, this.updated, this.profile, {this.pinned = false, this.messages = const []});

  final String id;
  final String title;
  final int updated;
  // null is OpenRouter. An empty string is the original Own Server connection.
  final String? profile;
  final bool pinned;
  final List<ChatMessage> messages;

  ChatThread copyWith({String? title, int? updated, bool? pinned, List<ChatMessage>? messages}) => ChatThread(
    id,
    title ?? this.title,
    updated ?? this.updated,
    profile,
    pinned: pinned ?? this.pinned,
    messages: messages ?? this.messages,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'updated': updated,
    'profile': profile,
    'pinned': pinned,
    'messages': [
      for (final message in messages)
        {
          'role': message.role,
          'text': message.text,
          if (message.attachments.isNotEmpty) 'attachments': message.attachments.map((file) => file.toJson()).toList(),
          if (message.incomplete) 'incomplete': true,
        },
    ],
  };

  factory ChatThread.fromJson(Map json) => ChatThread(
    json['id'] as String,
    json['title'] as String,
    json['updated'] as int,
    json['profile'] as String?,
    pinned: json['pinned'] as bool,
    messages: [
      for (final Map message in json['messages'] as List)
        (
          role: message['role'] as String,
          text: message['text'] as String,
          attachments: [
            if (message['attachments'] case final List files)
              for (final file in files.whereType<Map>()) ChatImage.fromJson(file)
            else if (message['image'] case final Map file)
              ChatImage.fromJson(file),
          ],
          incomplete: message['incomplete'] == true,
        ),
    ],
  );
}

class ChatFolder {
  const ChatFolder(this.id, this.name, this.threads, [this._sealed]);

  final String id;
  final String name;
  final List<ChatThread>? threads;
  final Map<String, Object?>? _sealed;

  bool get protected => _sealed != null;
  bool get locked => threads == null;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    if (_sealed case final sealed?) 'sealed': sealed else 'threads': _encodeThreads(threads!),
  };

  factory ChatFolder.fromJson(Map json) => ChatFolder(
    json['id'] as String,
    json['name'] as String,
    json.containsKey('sealed') ? null : _decodeThreads(json['threads']),
    (json['sealed'] as Map?)?.cast<String, Object?>(),
  );
}

List<Object?> _encodeThreads(List<ChatThread> threads) => [for (final thread in threads) thread.toJson()];
List<ChatThread> _decodeThreads(Object? json) => [for (final Map item in json as List) ChatThread.fromJson(item)];

final _random = Random.secure();
String _id() => base64UrlEncode(List<int>.generate(18, (_) => _random.nextInt(256)));
final _cipher = AesGcm.with256bits();

Future<SecretKey> _derive(String password, List<int> salt) => Isolate.run(
  () => Pbkdf2.hmacSha256(iterations: 600000, bits: 256).deriveKeyFromPassword(password: password, nonce: salt),
);

typedef _FolderKey = ({SecretKey key, String salt});

Future<Map<String, Object?>> _seal(String id, List<ChatThread> chats, _FolderKey secret) async {
  final box = await _cipher.encrypt(
    utf8.encode(jsonEncode(_encodeThreads(chats))),
    secretKey: secret.key,
    aad: utf8.encode(id),
  );
  return {'salt': secret.salt, 'box': base64Encode(box.concatenation())};
}

/// Protected folders have encrypted contents in every write. Moving a chat
/// updates the source and destination in the same library revision.
class ChatLibrary extends ChangeNotifier {
  ChatLibrary(String directory, {this.lockAfter}) : file = File(p.join(directory, 'chats.json')) {
    ready = _load();
  }

  final File file;
  Duration? lockAfter;
  late final Future<void> ready;
  bool loaded = false;
  Object? loadError;
  bool _disposed = false;
  String? _revision;
  Future<void> _queue = Future.value();
  List<ChatThread> _root = [];
  Map<String, ChatFolder> _folders = {};
  final _keys = <String, _FolderKey>{};
  final _timers = <String, Timer>{};
  final _unlockedAt = <String, DateTime>{};

  List<ChatFolder> get folders => List.unmodifiable(_folders.values);

  Iterable<({String? folder, ChatThread thread})> get visibleThreads sync* {
    for (final thread in _root) {
      yield (folder: null, thread: thread);
    }
    for (final folder in _folders.values) {
      for (final thread in folder.threads ?? const <ChatThread>[]) {
        yield (folder: folder.id, thread: thread);
      }
    }
  }

  Future<void> _load() async {
    try {
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map;
        if (data['version'] != 1) throw const FormatException('Unsupported chat library version');
        _revision = data['revision'] as String;
        _root = _decodeThreads(data['threads']);
        _folders = {for (final Map row in data['folders'] as List) row['id'] as String: ChatFolder.fromJson(row)};
      }
    } on Object catch (error) {
      loadError = error;
    } finally {
      loaded = true;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(Future<void> Function() work) {
    final next = _queue.catchError((Object _) {}).then((_) async {
      await ready;
      if (_disposed || loadError != null) throw StateError('Chat library is unavailable');
      await work();
    });
    _queue = next;
    return next;
  }

  Future<void> _save(List<ChatThread> root, Map<String, ChatFolder> folders) async {
    await file.parent.create(recursive: true);
    final lock = await File('${file.path}.lock').open(mode: FileMode.append);
    try {
      await lock.lock();
      final revision = await file.exists() ? (jsonDecode(await file.readAsString()) as Map)['revision'] : null;
      if (revision != _revision) throw StateError('The chat library changed in another window');
      final nextRevision = _id();
      final tmp = File('${file.path}.${_id()}.tmp');
      try {
        await tmp.writeAsString(
          jsonEncode({
            'version': 1,
            'revision': nextRevision,
            'threads': _encodeThreads(root),
            'folders': [for (final folder in folders.values) folder.toJson()],
          }),
          flush: true,
        );
        await tmp.rename(file.path);
      } finally {
        if (await tmp.exists()) await tmp.delete();
      }
      _revision = nextRevision;
      _root = root;
      _folders = folders;
    } finally {
      await lock.close();
    }
    _notify();
  }

  Future<void> addFolder(String name, {String? password}) => _run(() async {
    final id = _id();
    final secret = password == null ? null : await _newKey(password);
    final sealed = secret == null ? null : await _seal(id, [], secret);
    await _save(_root, {..._folders, id: ChatFolder(id, name, secret == null ? [] : null, sealed)});
  });

  Future<void> protect(String id, String password) => _run(() async {
    final folder = _folders[id]!;
    if (folder.protected) throw StateError('Folder already protected');
    final secret = await _newKey(password);
    final sealed = await _seal(id, folder.threads!, secret);
    await _save(_root, {..._folders, id: ChatFolder(id, folder.name, null, sealed)});
  });

  Future<_FolderKey> _newKey(String password) async {
    if (password.isEmpty) throw ArgumentError('Empty password');
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    return (key: await _derive(password, salt), salt: base64Encode(salt));
  }

  Future<void> unlock(String id, String password) => _run(() async {
    final folder = _folders[id]!;
    if (!folder.locked) return;
    final sealed = folder._sealed!;
    final salt = sealed['salt'] as String;
    final key = await _derive(password, base64Decode(salt));
    final box = SecretBox.fromConcatenation(
      base64Decode(sealed['box'] as String),
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final bytes = await _cipher.decrypt(box, secretKey: key, aad: utf8.encode(id));
    final chats = _decodeThreads(jsonDecode(utf8.decode(bytes)));
    if (_disposed) return;
    _keys[id] = (key: key, salt: salt);
    _unlockedAt[id] = DateTime.now();
    _folders[id] = ChatFolder(id, folder.name, chats, sealed);
    _startTimer(id);
    _notify();
  });

  void _startTimer(String id) {
    _timers.remove(id)?.cancel();
    if (lockAfter case final duration?) {
      final remaining = _unlockedAt[id]!.add(duration).difference(DateTime.now());
      _timers[id] = Timer(remaining, () => unawaited(lock(id).catchError((Object _) {})));
    }
  }

  void setLockAfter(Duration? duration) {
    if (duration == lockAfter) return;
    lockAfter = duration;
    for (final id in _keys.keys) {
      _startTimer(id);
    }
  }

  Future<void> lock(String id) => _run(() async {
    final folder = _folders[id];
    if (folder == null || !folder.protected) return;
    _timers.remove(id)?.cancel();
    _keys.remove(id);
    _unlockedAt.remove(id);
    _folders[id] = ChatFolder(id, folder.name, null, folder._sealed);
    _notify();
  });

  Future<String> addChat(String title, String? profile, {String? folder}) async {
    final id = _id();
    await _run(
      () => _writeThreads({
        folder: [..._threads(folder), ChatThread(id, title, _now(), profile)],
      }),
    );
    return id;
  }

  Future<void> edit(String id, ChatThread Function(ChatThread) update) => _run(() async {
    final item = visibleThreads.firstWhere((entry) => entry.thread.id == id);
    await _writeThreads({
      item.folder: [for (final chat in _threads(item.folder)) chat.id == id ? update(chat) : chat],
    });
  });

  Future<void> append(String id, ChatMessage message) =>
      edit(id, (chat) => chat.copyWith(updated: _now(), messages: [...chat.messages, message]));

  Future<void> delete(String id) => _run(() {
    final item = visibleThreads.firstWhere((entry) => entry.thread.id == id);
    return _writeThreads({item.folder: _threads(item.folder).where((chat) => chat.id != id).toList()});
  });

  Future<void> move(String id, String? target) => _run(() {
    final item = visibleThreads.firstWhere((entry) => entry.thread.id == id);
    if (item.folder == target) return Future.value();
    return _writeThreads({
      item.folder: _threads(item.folder).where((chat) => chat.id != id).toList(),
      target: [..._threads(target), item.thread],
    });
  });

  int _now() => DateTime.now().microsecondsSinceEpoch;

  List<ChatThread> _threads(String? id) =>
      id == null ? _root : _folders[id]?.threads ?? (throw StateError('Chat folder is locked'));

  Future<void> _writeThreads(Map<String?, List<ChatThread>> changed) async {
    final folders = {..._folders};
    for (final entry in changed.entries) {
      final id = entry.key;
      if (id == null) continue;
      final folder = _folders[id]!;
      final secret = _keys[id];
      if (folder.protected && secret == null) throw StateError('Chat folder is locked');
      final sealed = secret == null ? null : await _seal(id, entry.value, secret);
      folders[id] = ChatFolder(id, folder.name, entry.value, sealed);
    }
    await _save(changed[null] ?? _root, folders);
  }

  @override
  void dispose() {
    _disposed = true;
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _keys.clear();
    _unlockedAt.clear();
    super.dispose();
  }
}
