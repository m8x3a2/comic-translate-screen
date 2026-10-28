/// Image work in a background isolate, for code that also holds a `ref`, a
/// notifier or a widget.
///
/// In the Dart VM the closures of one function share its captured
/// variables, so a closure given to [Isolate.run] next to one that uses
/// `ref` or `this` takes them along and fails ("object is unsendable", see
/// the font suggestion fix). These functions are top-level and get plain
/// data only: call them instead of writing [Isolate.run] in such code.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:ct_core/ct_core.dart';

/// The colour image in [path].
Future<RgbImage> readImageInBackground(String path) => Isolate.run(() => ImageCodec.readFile(path));

/// The gray image (a mask) in [path].
Future<GrayImage> readGrayInBackground(String path) =>
    Isolate.run(() async => ImageCodec.decodeGray(await File(path).readAsBytes()));

/// The colour and the transparency of the image in [path].
Future<(RgbImage, GrayImage)> readRgbaInBackground(String path) =>
    Isolate.run(() async => ImageCodec.decodeRgba(await File(path).readAsBytes()));

/// Writes [image] to [path] as PNG.
Future<void> writePngInBackground(String path, RgbImage image) =>
    Isolate.run(() => File(path).writeAsBytes(ImageCodec.encodePng(image), flush: true));

/// Writes the Photoshop file [doc] to [path].
Future<void> writePsdInBackground(String path, PsdDocument doc) => Isolate.run(() => writePsdFile(path, doc));
