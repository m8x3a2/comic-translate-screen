/// Full screen (F11) and the window title. The Windows runner does them
/// natively (`windows/runner/flutter_window.cpp`); elsewhere they do nothing
/// until those platforms get their own code.
library;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const windowChannel = MethodChannel('comic_translate/window');

final fullScreenProvider = NotifierProvider<FullScreenNotifier, bool>(FullScreenNotifier.new);

class FullScreenNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Switches full screen on or off; returns whether it is on now.
  Future<bool> toggle() async {
    try {
      state = await windowChannel.invokeMethod<bool>('setFullScreen', !state) ?? false;
    } on MissingPluginException {
      // Not on Windows.
    }
    return state;
  }
}

/// Sets the title of the window (the project's name).
Future<void> setWindowTitle(String title) async {
  try {
    await windowChannel.invokeMethod<void>('setTitle', title);
  } on MissingPluginException {
    // Not on Windows.
  }
}
