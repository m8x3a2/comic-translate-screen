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
import 'dart:typed_data';

import 'package:ct_core/ct_core.dart';

/// The colour image in [path].
Future<RgbImage> readImageInBackground(String path) => Isolate.run(() => ImageCodec.readFile(path));

/// The gray image (a mask) in [path].
Future<GrayImage> readGrayInBackground(String path) =>
    Isolate.run(() async => ImageCodec.decodeGray(await File(path).readAsBytes()));

/// The mask pipette: [base] with the letters of [colours] in [regions] (see
/// `maskByColours`), as PNG.
Future<Uint8List> colourMaskPngInBackground(
  RgbImage image,
  GrayImage base,
  List<(int, int, int)> colours,
  double tolerance,
  List<BBox>? regions,
  int margin, {
  bool wholePieces = false,
}) => Isolate.run(
  () => ImageCodec.encodeGrayPng(
    maskByColours(image, base, colours, tolerance: tolerance, regions: regions, grow: margin, wholePieces: wholePieces),
  ),
);

/// The colour and the transparency of the image in [path].
Future<(RgbImage, GrayImage)> readRgbaInBackground(String path) =>
    Isolate.run(() async => ImageCodec.decodeRgba(await File(path).readAsBytes()));

/// The letters of [blocks] measured on the image in [path] (as after our
/// own reading), in order.
Future<List<SourceStyle?>> measureStylesInBackground(String path, List<TextBlock> blocks) => Isolate.run(() async {
  final image = await ImageCodec.readFile(path);
  return [for (final b in blocks) measureSourceStyle(image, b)];
});

/// "Find blocks inside": [block] of the page in [path] cut the way [mode]
/// says, the new blocks with lines for [sourceLanguage]; empty when there is
/// one block inside.
Future<List<TextBlock>> splitBlockInsideInBackground(
  String path,
  TextBlock block,
  InsideSplit mode,
  String sourceLanguage,
) => Isolate.run(() async {
  final image = await ImageCodec.readFile(path);
  return splitBlockInside(
    image,
    block,
    mode,
    annotateLines: (image, blocks) => annotateBlocksWithHeuristicLines(image, blocks, sourceLanguage: sourceLanguage),
  );
});

/// Writes [image] to [path] as PNG.
Future<void> writePngInBackground(String path, RgbImage image) =>
    Isolate.run(() => File(path).writeAsBytes(ImageCodec.encodePng(image), flush: true));

/// Writes the Photoshop file [doc] to [path].
Future<void> writePsdInBackground(String path, PsdDocument doc) => Isolate.run(() => writePsdFile(path, doc));

/// The fill of one click at ([x], [y]) on the image in [path] (see
/// [floodFillRuns]).
Future<List<int>> floodFillInBackground(String path, int x, int y, int tolerance, bool closeSpots) => Isolate.run(
  () async => floodFillRuns(await ImageCodec.readFile(path), x, y, tolerance: tolerance, closeSpots: closeSpots),
);
