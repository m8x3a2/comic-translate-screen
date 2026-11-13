/// The program icon (Settings → General → Program icon): the blue one built
/// into the exe, the navy one (second icon resource) or the user's picture.
///
/// The window and its taskbar button change at once (`setIcon` of the window
/// channel, WM_SETICON in `windows/runner/flutter_window.cpp`); shortcuts get
/// the icon by [updateShortcuts]. The exe's own icon in Explorer is fixed at
/// build time and stays blue.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'window_mode.dart' show windowChannel;

/// Picture files the user can pick for the icon.
const appIconPictureTypes = ['png', 'jpg', 'jpeg', 'bmp', 'webp', 'gif', 'ico'];

/// The settings value → what the window channel loads: `blue`, `navy` or the
/// path of the user's .ico (`blue` when that file is gone).
String appIconSource(String setting, AppPaths paths) {
  if (setting == 'navy') return 'navy';
  if (setting == 'custom' && paths.customIcon.existsSync()) return paths.customIcon.path;
  return 'blue';
}

/// Puts the icon on the window and its taskbar button. False when it could not
/// be loaded, or not on Windows.
Future<bool> applyAppIcon(String setting, AppPaths paths) async {
  if (!Platform.isWindows) return false;
  try {
    return await windowChannel.invokeMethod<bool>('setIcon', appIconSource(setting, paths)) ?? false;
  } on MissingPluginException {
    return false; // tests, cts
  } on PlatformException {
    return false;
  }
}

/// Makes the user's icon from [source]: a .ico is kept as it is; any other
/// picture is centred on a transparent square (nothing cut off) and drawn at
/// every icon size. Also writes [AppPaths.customIconPreview] for the settings.
/// Throws when the picture cannot be read.
Future<void> makeCustomIcon(String source, AppPaths paths) async {
  final bytes = await File(source).readAsBytes();
  final ico = paths.customIcon;
  await ico.parent.create(recursive: true);
  final isIco = p.extension(source).toLowerCase() == '.ico' || _looksLikeIco(bytes);
  ui.Image? picture;
  try {
    picture = await _decode(bytes);
  } on Exception {
    if (!isIco) rethrow; // a .ico Flutter cannot show still works for Windows
  }
  try {
    if (isIco) {
      await ico.writeAsBytes(bytes, flush: true);
    } else {
      final images = <IcoImage>[];
      for (final size in icoSizes) {
        final square = await _square(picture!, size);
        final rgba = (await square.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!.buffer.asUint8List();
        final png = size >= 256
            ? (await square.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List()
            : null;
        square.dispose();
        images.add(IcoImage(size, Uint8List.fromList(rgba), png: png));
      }
      await ico.writeAsBytes(encodeIco(images), flush: true);
    }
    final preview = paths.customIconPreview;
    if (picture != null) {
      final square = await _square(picture, 96);
      final png = (await square.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
      square.dispose();
      await preview.writeAsBytes(png, flush: true);
    } else if (preview.existsSync()) {
      await preview.delete();
    }
  } finally {
    picture?.dispose();
  }
  // a new file under the same name: the settings must not show the old one
  PaintingBinding.instance.imageCache.evict(FileImage(paths.customIconPreview));
}

bool _looksLikeIco(Uint8List b) => b.length > 6 && b[0] == 0 && b[1] == 0 && b[2] == 1 && b[3] == 0;

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// The picture fitted into a transparent [size]×[size] square. Big pictures
/// are halved step by step first, so small icons stay sharp, not grainy.
Future<ui.Image> _square(ui.Image src, int size) async {
  var img = src;
  var owned = false;
  while (img.width > size * 2 && img.height > size * 2) {
    final half = await _draw(img, img.width ~/ 2, img.height ~/ 2, Rect.fromLTWH(0, 0, img.width / 2, img.height / 2));
    if (owned) img.dispose();
    img = half;
    owned = true;
  }
  final scale = size / (img.width > img.height ? img.width : img.height);
  final w = img.width * scale, h = img.height * scale;
  final out = await _draw(img, size, size, Rect.fromLTWH((size - w) / 2, (size - h) / 2, w, h));
  if (owned) img.dispose();
  return out;
}

Future<ui.Image> _draw(ui.Image img, int width, int height, Rect dst) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    dst,
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  return picture.toImage(width, height).whenComplete(picture.dispose);
}

/// What a shortcut's icon points at: the exe's own icons by number (0 blue,
/// 1 navy) or the user's .ico.
String shortcutIconLocation(String setting, AppPaths paths) {
  final source = appIconSource(setting, paths);
  final exe = Platform.resolvedExecutable;
  return switch (source) {
    'blue' => '$exe,0',
    'navy' => '$exe,1',
    _ => '$source,0',
  };
}

/// Gives the program's shortcuts (desktop, Start menu, pinned to the
/// taskbar) the icon [iconLocation]. Returns how many were changed; shortcuts
/// in shared folders that need administrator rights are skipped.
Future<int> updateShortcuts(String iconLocation) async {
  final out = await _powerShell('''
\$exe = ${_psString(Platform.resolvedExecutable)}
\$icon = ${_psString(iconLocation)}
\$sh = New-Object -ComObject WScript.Shell
\$dirs = @(
  [Environment]::GetFolderPath('Desktop'),
  [Environment]::GetFolderPath('CommonDesktopDirectory'),
  [Environment]::GetFolderPath('Programs'),
  [Environment]::GetFolderPath('CommonPrograms'),
  (Join-Path \$env:APPDATA 'Microsoft\\Internet Explorer\\Quick Launch\\User Pinned\\TaskBar')
)
\$n = 0
foreach (\$d in \$dirs) {
  if (\$d -and (Test-Path -LiteralPath \$d)) {
    Get-ChildItem -LiteralPath \$d -Filter *.lnk -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
      try {
        \$l = \$sh.CreateShortcut(\$_.FullName)
        if (\$l.TargetPath -ieq \$exe) { \$l.IconLocation = \$icon; \$l.Save(); \$n++ }
      } catch {}
    }
  }
}
\$n
''');
  await _refreshShellIcons();
  return int.tryParse(out.trim().split(RegExp(r'\s+')).last) ?? 0;
}

/// Puts a shortcut to the program on the desktop with the icon
/// [iconLocation]; returns its path.
Future<String> createDesktopShortcut(String iconLocation) async {
  final exe = Platform.resolvedExecutable;
  final out = await _powerShell('''
\$sh = New-Object -ComObject WScript.Shell
\$path = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Comic Translate Screen.lnk'
\$l = \$sh.CreateShortcut(\$path)
\$l.TargetPath = ${_psString(exe)}
\$l.WorkingDirectory = ${_psString(p.dirname(exe))}
\$l.IconLocation = ${_psString(iconLocation)}
\$l.Save()
\$path
''');
  await _refreshShellIcons();
  return out.trim().split(RegExp(r'[\r\n]+')).last;
}

Future<void> _refreshShellIcons() async {
  try {
    await windowChannel.invokeMethod<void>('refreshShellIcons');
  } on MissingPluginException {
    // not the window app
  }
}

/// A PowerShell string literal ('' doubles a quote).
String _psString(String s) => "'${s.replaceAll("'", "''")}'";

/// Runs [script] in Windows PowerShell; the script travels as UTF-16 Base64,
/// so paths with any letters survive. Throws when it fails.
Future<String> _powerShell(String script) async {
  final utf8Out = '[Console]::OutputEncoding = [Text.Encoding]::UTF8\n$script';
  final units = utf8Out.codeUnits;
  final bytes = Uint8List(units.length * 2);
  for (var i = 0; i < units.length; i++) {
    bytes[i * 2] = units[i] & 0xFF;
    bytes[i * 2 + 1] = units[i] >> 8;
  }
  final r = await Process.run('powershell.exe', [
    '-NoProfile',
    '-NonInteractive',
    '-ExecutionPolicy',
    'Bypass',
    '-EncodedCommand',
    base64.encode(bytes),
  ], stdoutEncoding: utf8);
  if (r.exitCode != 0) throw ProcessException('powershell.exe', const [], '${r.stderr}'.trim(), r.exitCode);
  return '${r.stdout}';
}
