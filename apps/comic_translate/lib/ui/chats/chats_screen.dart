import 'package:ct_core/ct_core.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../services/chat_library.dart';
import '../../state/app_state.dart';
import '../common/labels.dart';
import '../settings/translator_test_chat.dart';

const _pathKey = 'chat_library_directory';
const _timeoutKey = 'chat_folder_lock_minutes';
const _openRouter = '@openrouter';

final _libraryProvider = Provider<ChatLibrary>((ref) {
  final directory = ref.watch(settingsProvider.select((s) => s.extra[_pathKey] as String?));
  final paths = ref.read(servicesProvider).paths;
  final library = ChatLibrary(directory ?? p.join(paths.root.path, 'chats'));
  void configure(Object? minutes) =>
      library.setLockAfter(minutes == 30 || minutes == 60 ? Duration(minutes: minutes as int) : null);
  configure(ref.read(settingsProvider).extra[_timeoutKey]);
  ref.listen(settingsProvider.select((s) => s.extra[_timeoutKey]), (_, next) => configure(next));
  ref.onDispose(library.dispose);
  return library;
});

void showChats(BuildContext context) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ChatsScreen()));
}

class ChatsScreen extends ConsumerWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(_libraryProvider);
    return _ChatsWorkspace(key: ObjectKey(library), library: library);
  }
}

enum _ChatAction { rename, pin, move, delete }

class _ChatsWorkspace extends ConsumerStatefulWidget {
  const _ChatsWorkspace({super.key, required this.library});

  final ChatLibrary library;

  @override
  ConsumerState<_ChatsWorkspace> createState() => _ChatsWorkspaceState();
}

class _ChatsWorkspaceState extends ConsumerState<_ChatsWorkspace> {
  ChatLibrary get _library => widget.library;
  String? _folder;
  String? _selected;
  String _search = '';
  bool _busy = false;

  Future<void> _write(Future<void> Function() work, {bool password = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await work();
    } on Exception {
      if (mounted) _error(password ? context.l10n.chatUnlockError : context.l10n.chatStorageError);
    } on StateError {
      if (mounted) _error(context.l10n.chatStorageError);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _error(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  String _profileName(AppSettings settings, String? profile) => switch (profile) {
    null => 'OpenRouter',
    '' => context.l10n.ownServerOriginal,
    _ => settings.ownServerNames[profile] ?? context.l10n.chatConnectionMissing,
  };

  Future<void> _newChat(AppSettings settings) async {
    final l = context.l10n;
    var name = l.chatUntitled;
    var connection = settings.translator == 'openai_compatible' ? settings.ownServerProfile : _openRouter;
    if (connection.isNotEmpty && connection != _openRouter && !settings.ownServerNames.containsKey(connection)) {
      connection = '';
    }
    final options = [
      const MapEntry(_openRouter, 'OpenRouter'),
      MapEntry('', l.chatOwnServerOriginal),
      for (final entry in settings.ownServerNames.entries) MapEntry(entry.key, l.chatOwnServerNamed(entry.value)),
    ];
    final result = await showDialog<({String title, String? profile})>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.chatNew),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: name,
                onChanged: (value) => name = value,
                maxLength: 100,
                decoration: InputDecoration(labelText: l.chatThreadTitle),
              ),
              DropdownButtonFormField<String>(
                initialValue: connection,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.chatConnection),
                items: [
                  for (final option in options)
                    DropdownMenuItem(
                      value: option.key,
                      child: Text(option.value, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) => connection = value ?? _openRouter,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              final title = name.trim();
              Navigator.pop(dialog, (
                title: title.isEmpty ? l.chatUntitled : title,
                profile: connection == _openRouter ? null : connection,
              ));
            },
            child: Text(l.chatCreate),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await _write(() async {
      final id = await _library.addChat(result.title, result.profile, folder: _folder);
      if (mounted) setState(() => _selected = id);
    });
  }

  Future<String?> _input(
    String title,
    String label, {
    String initial = '',
    bool password = false,
    bool repeat = false,
  }) {
    final l = context.l10n;
    final form = GlobalKey<FormState>();
    var text = initial;
    var showPassword = false;
    return showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 390,
          child: StatefulBuilder(
            builder: (context, setDialogState) => Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (repeat) Text(l.chatPasswordHelp),
                  TextFormField(
                    autofocus: true,
                    initialValue: initial,
                    obscureText: password && !showPassword,
                    maxLength: password ? 256 : 100,
                    decoration: InputDecoration(
                      labelText: label,
                      suffixIcon: password
                          ? IconButton(
                              tooltip: showPassword ? l.secretHide : l.secretShow,
                              onPressed: () => setDialogState(() => showPassword = !showPassword),
                              icon: Icon(showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            )
                          : null,
                    ),
                    onChanged: (value) => text = value,
                    validator: (value) =>
                        (password ? value : value?.trim())?.isNotEmpty == true ? null : l.chatRequired,
                  ),
                  if (repeat)
                    TextFormField(
                      obscureText: !showPassword,
                      decoration: InputDecoration(labelText: l.chatRepeatPassword),
                      validator: (value) => value == text ? null : l.chatPasswordMismatch,
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(dialog, password ? text : text.trim());
            },
            child: Text(password && !repeat ? l.chatUnlock : l.save),
          ),
        ],
      ),
    );
  }

  Future<void> _newFolder() async {
    final l = context.l10n;
    final name = await _input(l.chatNewFolder, l.chatFolderName);
    if (name != null && mounted) await _write(() => _library.addFolder(name));
  }

  void _selectFolder(String? folder) => setState(() {
    _folder = folder;
    _selected = null;
  });

  Future<void> _openFolder(ChatFolder folder) async {
    if (!folder.locked) {
      _selectFolder(folder.id);
      return;
    }
    final l = context.l10n;
    final password = await _input(l.chatUnlock, l.chatPassword, password: true);
    if (password == null || !mounted) return;
    await _write(() async {
      await _library.unlock(folder.id, password);
      if (mounted) _selectFolder(folder.id);
    }, password: true);
  }

  Future<void> _protect(ChatFolder folder) async {
    final l = context.l10n;
    final password = await _input(l.chatProtect, l.chatPassword, password: true, repeat: true);
    if (password != null && mounted) await _write(() => _library.protect(folder.id, password));
  }

  Future<void> _chatAction(_ChatAction action, ChatThread thread, String? folder) async {
    final l = context.l10n;
    switch (action) {
      case _ChatAction.rename:
        final name = await _input(l.chatRename, l.chatThreadTitle, initial: thread.title);
        if (name != null && mounted) await _write(() => _library.edit(thread.id, (chat) => chat.copyWith(title: name)));
      case _ChatAction.pin:
        await _write(() => _library.edit(thread.id, (chat) => chat.copyWith(pinned: !chat.pinned)));
      case _ChatAction.move:
        final target = await showDialog<({String? folder})>(
          context: context,
          builder: (dialog) => SimpleDialog(
            title: Text(l.chatMove),
            children: [
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text(l.chatMovePrivacy)),
              if (folder != null)
                SimpleDialogOption(onPressed: () => Navigator.pop(dialog, (folder: null)), child: Text(l.chatNoFolder)),
              for (final target in _library.folders.where((item) => item.id != folder && !item.locked))
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialog, (folder: target.id)),
                  child: Text(target.name),
                ),
              if (_library.folders.any((item) => item.locked))
                Padding(padding: const EdgeInsets.all(16), child: Text(l.chatUnlockToMove)),
            ],
          ),
        );
        if (target != null && mounted) {
          await _write(() async {
            await _library.move(thread.id, target.folder);
            if (mounted) {
              setState(() {
                _folder = target.folder;
                _selected = thread.id;
              });
            }
          });
        }
      case _ChatAction.delete:
        final approved = await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            title: Text(l.chatDelete),
            content: Text(thread.title),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l.delete)),
            ],
          ),
        );
        if (approved == true && mounted) await _write(() => _library.delete(thread.id));
    }
  }

  Future<void> _settings(AppSettings settings) async {
    final l = context.l10n;
    var path = _library.file.parent.path;
    var minutes = settings.extra[_timeoutKey] as int? ?? 0;
    if (minutes != 30 && minutes != 60) minutes = 0;
    final change = await showDialog<({String path, int minutes})>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(l.chatStorageSettings),
          content: SizedBox(
            width: 490,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.chatStorageHelp),
                const SizedBox(height: 8),
                SelectableText(path),
                TextButton.icon(
                  onPressed: () async {
                    final next = await getDirectoryPath(initialDirectory: path);
                    if (next != null && context.mounted) update(() => path = p.normalize(next));
                  },
                  icon: const Icon(Icons.folder_open_outlined),
                  label: Text(l.chatChooseLocation),
                ),
                DropdownButtonFormField<int>(
                  initialValue: minutes,
                  decoration: InputDecoration(labelText: l.chatRelock),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(l.chatRelockRestart)),
                    DropdownMenuItem(value: 30, child: Text(l.chatRelock30)),
                    DropdownMenuItem(value: 60, child: Text(l.chatRelock60)),
                  ],
                  onChanged: (value) => minutes = value ?? 0,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialog, (path: path, minutes: minutes)), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (change == null || !mounted) return;
    await _write(
      () => ref.read(settingsProvider.notifier).change((s) {
        final current = s.extra[_pathKey];
        if (current != null || change.path != _library.file.parent.path) s.extra[_pathKey] = change.path;
        s.extra[_timeoutKey] = change.minutes;
      }),
    );
  }

  Widget _conversation(ChatThread thread, AppSettings settings) {
    final services = ref.read(servicesProvider);
    final profile = thread.profile;
    final plugin = profile == null ? 'openrouter' : 'openai_compatible';
    final available =
        services.registry.contains(plugin) &&
        (profile == null || profile.isEmpty || settings.ownServerNames.containsKey(profile));
    final connection = AppSettings.fromJson(settings.toJson())..ownServerProfile = profile ?? '';
    final config = available
        ? PluginConfig.resolve(services.registry.info(plugin).settings, connection.pluginValues(plugin))
        : null;
    return ChatConversation(
      key: ValueKey(thread.id),
      pluginId: plugin,
      host: _profileName(settings, profile),
      model: config?.value<String>('model') ?? '',
      thread: thread,
      connection: connection,
      connectionAvailable: available,
      append: (message) => _library.append(thread.id, message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final settings = ref.watch(settingsProvider);
    return ListenableBuilder(
      listenable: _library,
      builder: (context, _) {
        final folders = _library.folders;
        final active = folders.where((folder) => folder.id == _folder).firstOrNull;
        final items = _library.visibleThreads.toList()
          ..sort((a, b) {
            if (a.thread.pinned != b.thread.pinned) return a.thread.pinned ? -1 : 1;
            return b.thread.updated.compareTo(a.thread.updated);
          });
        final selected = items.where((item) => item.thread.id == _selected).firstOrNull?.thread;
        final visible = items
            .where(
              (item) =>
                  (_folder == null || item.folder == _folder) && item.thread.title.toLowerCase().contains(_search),
            )
            .toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(l.chatsWorkspace),
            actions: [
              IconButton(
                tooltip: l.chatStorageSettings,
                onPressed: _busy ? null : () => _settings(settings),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          body: !_library.loaded
              ? const Center(child: CircularProgressIndicator())
              : _library.loadError != null
              ? Center(child: Text(l.chatStorageError))
              : Column(
                  children: [
                    if (_busy) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
                    Expanded(
                      child: Row(
                        children: [
                          SizedBox(
                            width: 290,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          onPressed: _busy || (active?.locked ?? false)
                                              ? null
                                              : () => _newChat(settings),
                                          icon: const Icon(Icons.add),
                                          label: Text(l.chatNew),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: l.chatNewFolder,
                                        onPressed: _busy ? null : _newFolder,
                                        icon: const Icon(Icons.create_new_folder_outlined),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: TextField(
                                    decoration: InputDecoration(
                                      prefixIcon: const Icon(Icons.search),
                                      labelText: l.chatTitleSearch,
                                    ),
                                    onChanged: (value) => setState(() => _search = value.trim().toLowerCase()),
                                  ),
                                ),
                                ListTile(
                                  dense: true,
                                  leading: const Icon(Icons.forum_outlined),
                                  title: Text(l.chatAll),
                                  selected: _folder == null,
                                  onTap: () => _selectFolder(null),
                                ),
                                if (folders.isNotEmpty)
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxHeight: 148),
                                    child: ListView(
                                      shrinkWrap: true,
                                      children: [
                                        for (final folder in folders)
                                          ListTile(
                                            dense: true,
                                            leading: Icon(folder.locked ? Icons.lock_outline : Icons.folder_outlined),
                                            title: Text(folder.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                            selected: _folder == folder.id,
                                            onTap: _busy ? null : () => _openFolder(folder),
                                            trailing: folder.locked
                                                ? null
                                                : IconButton(
                                                    tooltip: folder.protected ? l.chatLock : l.chatProtect,
                                                    icon: Icon(folder.protected ? Icons.lock_open : Icons.password),
                                                    onPressed: _busy
                                                        ? null
                                                        : () {
                                                            if (folder.protected) {
                                                              _write(() => _library.lock(folder.id));
                                                            } else {
                                                              _protect(folder);
                                                            }
                                                          },
                                                  ),
                                          ),
                                      ],
                                    ),
                                  ),
                                const Divider(),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: visible.length,
                                    itemBuilder: (context, index) {
                                      final item = visible[index];
                                      final thread = item.thread;
                                      return ListTile(
                                        dense: true,
                                        selected: thread.id == _selected,
                                        title: Text(thread.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                                        leading: Icon(thread.pinned ? Icons.push_pin : Icons.chat_bubble_outline),
                                        onTap: _busy ? null : () => setState(() => _selected = thread.id),
                                        trailing: PopupMenuButton<_ChatAction>(
                                          enabled: !_busy,
                                          onSelected: (action) => _chatAction(action, thread, item.folder),
                                          itemBuilder: (_) => [
                                            PopupMenuItem(value: _ChatAction.rename, child: Text(l.chatRename)),
                                            PopupMenuItem(
                                              value: _ChatAction.pin,
                                              child: Text(thread.pinned ? l.chatUnpin : l.chatPin),
                                            ),
                                            if (item.folder != null || folders.any((folder) => !folder.locked))
                                              PopupMenuItem(value: _ChatAction.move, child: Text(l.chatMove)),
                                            PopupMenuItem(value: _ChatAction.delete, child: Text(l.chatDelete)),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: selected != null
                                  ? _conversation(selected, settings)
                                  : Center(
                                      child: (active?.locked ?? false)
                                          ? OutlinedButton.icon(
                                              onPressed: _busy ? null : () => _openFolder(active!),
                                              icon: const Icon(Icons.lock_open),
                                              label: Text(l.chatUnlock),
                                            )
                                          : Text(l.chatChoose),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
