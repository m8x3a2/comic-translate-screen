// Keyboard shortcuts: stored names, defaults, changing and resetting keys.

import 'package:comic_translate/ui/common/key_bindings.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every default key is stored and read back by name', () {
    for (final keys in defaultShortcuts.values) {
      for (final k in keys) {
        expect(KeyCombo.parse(k.toString()), k, reason: '$k');
      }
    }
    expect(const KeyCombo(LogicalKeyboardKey.keyS, ctrl: true, shift: true).toString(), 'Ctrl+Shift+S');
    expect(KeyCombo.parse('Ctrl++'), const KeyCombo(LogicalKeyboardKey.add, ctrl: true));
    expect(KeyCombo.parse('Hyper+S'), isNull);
    expect(KeyCombo.parse(''), isNull);
    expect(ShortcutAction.values.map((a) => a.id).toSet(), hasLength(ShortcutAction.values.length));
    expect(defaultShortcuts.keys.toSet(), ShortcutAction.values.toSet());
  });

  test('no key does two things by default', () {
    final seen = <KeyCombo>{};
    for (final keys in defaultShortcuts.values) {
      for (final k in keys) {
        expect(seen.add(k), isTrue, reason: '$k');
      }
    }
  });

  test('keys that work while typing; keys left to text fields', () {
    expect(const KeyCombo(LogicalKeyboardKey.keyS, ctrl: true).global, isTrue);
    expect(const KeyCombo(LogicalKeyboardKey.f1).global, isTrue);
    expect(const KeyCombo(LogicalKeyboardKey.keyT).global, isFalse);
    expect(const KeyCombo(LogicalKeyboardKey.pageDown).global, isFalse);
    expect(const KeyCombo(LogicalKeyboardKey.keyC, ctrl: true).reserved, isTrue);
    expect(const KeyCombo(LogicalKeyboardKey.enter).reserved, isTrue);
    expect(const KeyCombo(LogicalKeyboardKey.space).reserved, isTrue);
    expect(const KeyCombo(LogicalKeyboardKey.enter, ctrl: true).reserved, isFalse);
    expect(const KeyCombo(LogicalKeyboardKey.keyC, ctrl: true, shift: true).reserved, isFalse);
  });

  test('a new key: taken from the action that had it; reset takes it back', () {
    final s = AppSettings();
    const ctrlY = KeyCombo(LogicalKeyboardKey.keyY, ctrl: true);
    const ctrlU = KeyCombo(LogicalKeyboardKey.keyU, ctrl: true);
    setShortcut(s, ShortcutAction.undo, ctrlU);
    var keys = KeyBindings.of(s);
    expect(keys.keysOf(ShortcutAction.undo), [ctrlU]);
    expect(keys.actionOf(const KeyCombo(LogicalKeyboardKey.keyZ, ctrl: true)), isNull);

    // Ctrl+Y goes from redo to undo; redo keeps its other key.
    setShortcut(s, ShortcutAction.undo, ctrlY);
    keys = KeyBindings.of(s);
    expect(keys.actionOf(ctrlY), ShortcutAction.undo);
    expect(keys.labelOf(ShortcutAction.redo), 'Ctrl+Shift+Z');

    // No key at all.
    setShortcut(s, ShortcutAction.help, null);
    expect(KeyBindings.of(s).keysOf(ShortcutAction.help), isEmpty);
    expect(s.shortcuts['help'], '');

    // Back to the default: Ctrl+Y returns to redo, undo is left without it.
    resetShortcut(s, ShortcutAction.redo);
    keys = KeyBindings.of(s);
    expect(keys.labelOf(ShortcutAction.redo), 'Ctrl+Y, Ctrl+Shift+Z');
    expect(keys.keysOf(ShortcutAction.undo), isEmpty);

    // The default key chosen again is not stored.
    setShortcut(s, ShortcutAction.help, const KeyCombo(LogicalKeyboardKey.f1));
    expect(s.shortcuts.containsKey('help'), isFalse);
  });

  test('a key written into the settings by hand is not used twice', () {
    final s = AppSettings(shortcuts: {'find': 'T'});
    final keys = KeyBindings.of(s);
    expect(keys.actionOf(const KeyCombo(LogicalKeyboardKey.keyT)), ShortcutAction.find);
    expect(keys.keysOf(ShortcutAction.text), isEmpty);
    expect(KeyBindings.of(AppSettings(shortcuts: {'undo': 'nonsense'})).keysOf(ShortcutAction.undo), isEmpty);
  });
}
