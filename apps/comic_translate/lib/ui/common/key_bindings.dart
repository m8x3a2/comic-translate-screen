/// Keyboard shortcuts that the user can change (original `app/shortcuts.py`
/// and its settings page): the actions, their default keys, and the keys
/// chosen in the settings ([AppSettings.shortcuts], only the changed ones).
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/services.dart';

/// A key with Ctrl, Shift and Alt pressed or not.
class KeyCombo {
  const KeyCombo(this.key, {this.ctrl = false, this.shift = false, this.alt = false});

  final LogicalKeyboardKey key;
  final bool ctrl;
  final bool shift;
  final bool alt;

  /// The combination of a key event, or null for a modifier key alone.
  static KeyCombo? ofEvent(KeyEvent e, HardwareKeyboard keyboard) {
    if (_modifiers.contains(e.logicalKey)) return null;
    return KeyCombo(
      e.logicalKey,
      ctrl: keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
    );
  }

  /// `Ctrl+Shift+S`, `Page Down`, `[`; null when not understood.
  static KeyCombo? parse(String text) {
    if (text.isEmpty) return null;
    final parts = text.split('+');
    // "Ctrl++": the plus key.
    if (text.endsWith('++')) {
      parts
        ..removeRange(parts.length - 2, parts.length)
        ..add('+');
    }
    var ctrl = false, shift = false, alt = false;
    for (final m in parts.take(parts.length - 1)) {
      switch (m) {
        case 'Ctrl':
          ctrl = true;
        case 'Shift':
          shift = true;
        case 'Alt':
          alt = true;
        default:
          return null;
      }
    }
    final key = _byLabel[parts.last];
    return key == null ? null : KeyCombo(key, ctrl: ctrl, shift: shift, alt: alt);
  }

  /// The key's name as shown and stored.
  static String keyName(LogicalKeyboardKey key) => switch (key) {
    LogicalKeyboardKey.escape => 'Esc',
    LogicalKeyboardKey.pageUp => 'PageUp',
    LogicalKeyboardKey.pageDown => 'PageDown',
    _ => key.keyLabel.isEmpty ? key.debugName ?? '?' : key.keyLabel,
  };

  static final Map<String, LogicalKeyboardKey> _byLabel = () {
    final map = <String, LogicalKeyboardKey>{};
    for (final k in LogicalKeyboardKey.knownLogicalKeys) {
      if (_modifiers.contains(k)) continue;
      map.putIfAbsent(keyName(k), () => k);
    }
    return map;
  }();

  static final _modifiers = {
    LogicalKeyboardKey.control,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shift,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.alt,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.meta,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.numLock,
    LogicalKeyboardKey.fn,
  };

  bool get isFunctionKey => key.keyId >= LogicalKeyboardKey.f1.keyId && key.keyId <= LogicalKeyboardKey.f24.keyId;

  /// Works while a text field has the focus: with Ctrl or Alt, or a
  /// function key. Other keys type text or move the cursor there.
  bool get global => ctrl || alt || isFunctionKey;

  /// Taken by text fields, buttons and dialogs: not offered for actions.
  bool get reserved {
    final plain = !ctrl && !alt;
    if (plain &&
        {
          LogicalKeyboardKey.tab,
          LogicalKeyboardKey.enter,
          LogicalKeyboardKey.numpadEnter,
          LogicalKeyboardKey.space,
        }.contains(key)) {
      return true;
    }
    if (ctrl && !alt && !shift) {
      return {
        LogicalKeyboardKey.keyC,
        LogicalKeyboardKey.keyV,
        LogicalKeyboardKey.keyX,
        LogicalKeyboardKey.keyA,
      }.contains(key);
    }
    return false;
  }

  @override
  String toString() => [if (ctrl) 'Ctrl', if (shift) 'Shift', if (alt) 'Alt', keyName(key)].join('+');

  @override
  bool operator ==(Object other) =>
      other is KeyCombo && other.key == key && other.ctrl == ctrl && other.shift == shift && other.alt == alt;

  @override
  int get hashCode => Object.hash(key, ctrl, shift, alt);
}

/// Groups of the F1 window and of the settings page.
enum ShortcutGroup { files, tools, edit, window }

/// Everything a key can do. [id] is stored in the settings.
enum ShortcutAction {
  open('open', ShortcutGroup.files),
  save('save', ShortcutGroup.files),
  saveAs('save_as', ShortcutGroup.files),
  translateAll('translate_all', ShortcutGroup.files),
  previousPage('previous_page', ShortcutGroup.files),
  nextPage('next_page', ShortcutGroup.files),
  pan('tool_pan', ShortcutGroup.tools),
  boxes('tool_boxes', ShortcutGroup.tools),
  text('tool_text', ShortcutGroup.tools),
  brush('tool_brush', ShortcutGroup.tools),
  eraser('tool_eraser', ShortcutGroup.tools),
  brushSmaller('brush_smaller', ShortcutGroup.tools),
  brushLarger('brush_larger', ShortcutGroup.tools),
  undo('undo', ShortcutGroup.edit),
  redo('redo', ShortcutGroup.edit),
  deleteBox('delete_box', ShortcutGroup.edit),
  deselect('deselect', ShortcutGroup.edit),
  find('find', ShortcutGroup.edit),
  help('help', ShortcutGroup.window),
  fullScreen('full_screen', ShortcutGroup.window);

  const ShortcutAction(this.id, this.group);

  final String id;
  final ShortcutGroup group;

  /// Undo, redo and deleting belong to a text field while one is focused,
  /// whatever the keys.
  bool get yieldsToTyping => this == undo || this == redo || this == deleteBox;
}

KeyCombo _ctrl(LogicalKeyboardKey k, {bool shift = false}) => KeyCombo(k, ctrl: true, shift: shift);

/// The keys of each action until the user changes them (the original's
/// defaults where it has the action).
final defaultShortcuts = <ShortcutAction, List<KeyCombo>>{
  ShortcutAction.open: [_ctrl(LogicalKeyboardKey.keyO)],
  ShortcutAction.save: [_ctrl(LogicalKeyboardKey.keyS)],
  ShortcutAction.saveAs: [_ctrl(LogicalKeyboardKey.keyS, shift: true)],
  ShortcutAction.translateAll: [_ctrl(LogicalKeyboardKey.enter)],
  ShortcutAction.previousPage: [const KeyCombo(LogicalKeyboardKey.pageUp)],
  ShortcutAction.nextPage: [const KeyCombo(LogicalKeyboardKey.pageDown)],
  ShortcutAction.pan: [const KeyCombo(LogicalKeyboardKey.keyH), const KeyCombo(LogicalKeyboardKey.keyV)],
  ShortcutAction.boxes: [const KeyCombo(LogicalKeyboardKey.keyR)],
  ShortcutAction.text: [const KeyCombo(LogicalKeyboardKey.keyT)],
  ShortcutAction.brush: [const KeyCombo(LogicalKeyboardKey.keyB)],
  ShortcutAction.eraser: [const KeyCombo(LogicalKeyboardKey.keyE)],
  ShortcutAction.brushSmaller: [const KeyCombo(LogicalKeyboardKey.bracketLeft)],
  ShortcutAction.brushLarger: [const KeyCombo(LogicalKeyboardKey.bracketRight)],
  ShortcutAction.undo: [_ctrl(LogicalKeyboardKey.keyZ)],
  ShortcutAction.redo: [_ctrl(LogicalKeyboardKey.keyY), _ctrl(LogicalKeyboardKey.keyZ, shift: true)],
  ShortcutAction.deleteBox: [const KeyCombo(LogicalKeyboardKey.delete), const KeyCombo(LogicalKeyboardKey.backspace)],
  ShortcutAction.deselect: [const KeyCombo(LogicalKeyboardKey.escape)],
  ShortcutAction.find: [_ctrl(LogicalKeyboardKey.keyF), _ctrl(LogicalKeyboardKey.keyH)],
  ShortcutAction.help: [const KeyCombo(LogicalKeyboardKey.f1)],
  ShortcutAction.fullScreen: [const KeyCombo(LogicalKeyboardKey.f11)],
};

/// The keys of every action: the defaults, with the user's changes (one
/// combination each, or none).
class KeyBindings {
  KeyBindings._(this._keys);

  factory KeyBindings.of(AppSettings settings) {
    final keys = {for (final e in defaultShortcuts.entries) e.key: List.of(e.value)};
    for (final a in ShortcutAction.values) {
      final custom = settings.shortcuts[a.id];
      if (custom == null) continue;
      final combo = KeyCombo.parse(custom);
      keys[a] = [?combo];
    }
    // A combination changed onto one action leaves the defaults of others.
    for (final a in ShortcutAction.values) {
      if (settings.shortcuts.containsKey(a.id)) continue;
      keys[a] = [
        for (final k in keys[a]!)
          if (!ShortcutAction.values.any((o) => o != a && settings.shortcuts.containsKey(o.id) && keys[o]!.contains(k)))
            k,
      ];
    }
    return KeyBindings._(keys);
  }

  final Map<ShortcutAction, List<KeyCombo>> _keys;

  List<KeyCombo> keysOf(ShortcutAction action) => _keys[action] ?? const [];

  /// The keys as shown: `Ctrl+Y, Ctrl+Shift+Z`, or empty.
  String labelOf(ShortcutAction action) => keysOf(action).join(', ');

  /// The action of [combo], if any.
  ShortcutAction? actionOf(KeyCombo combo) {
    for (final e in _keys.entries) {
      if (e.value.contains(combo)) return e.key;
    }
    return null;
  }

  /// The action of a key event; while [typing] in a text field only global
  /// combinations count (see [KeyCombo.global]).
  ShortcutAction? actionFor(KeyEvent e, {required bool typing, HardwareKeyboard? keyboard}) {
    final combo = KeyCombo.ofEvent(e, keyboard ?? HardwareKeyboard.instance);
    if (combo == null) return null;
    final action = actionOf(combo);
    if (action == null) return null;
    if (typing && (!combo.global || action.yieldsToTyping)) return null;
    return action;
  }
}

/// [settings] with [combo] as the only key of [action] (null: no key). Taken
/// from another action that had it; the default comes back when it equals
/// the default.
void setShortcut(AppSettings settings, ShortcutAction action, KeyCombo? combo) {
  final current = KeyBindings.of(settings);
  if (combo != null) {
    final other = current.actionOf(combo);
    if (other != null && other != action) {
      final rest = [
        for (final k in current.keysOf(other))
          if (k != combo) k,
      ];
      settings.shortcuts[other.id] = rest.isEmpty ? '' : rest.first.toString();
    }
  }
  final defaults = defaultShortcuts[action]!;
  if (combo != null && defaults.length == 1 && defaults.single == combo) {
    settings.shortcuts.remove(action.id);
  } else {
    settings.shortcuts[action.id] = combo?.toString() ?? '';
  }
}

/// [action] back to its default keys, taken back from actions that were
/// given one of them.
void resetShortcut(AppSettings settings, ShortcutAction action) {
  settings.shortcuts.remove(action.id);
  for (final combo in defaultShortcuts[action]!) {
    for (final other in ShortcutAction.values) {
      if (other != action && KeyCombo.parse(settings.shortcuts[other.id] ?? '') == combo) {
        settings.shortcuts[other.id] = '';
      }
    }
  }
}

/// Set while the settings wait for a new key, so that no other handler acts
/// on it (F11 would switch the full screen).
var capturingShortcut = false;
