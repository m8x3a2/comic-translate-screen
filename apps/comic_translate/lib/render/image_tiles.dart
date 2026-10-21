/// Pictures taller than the graphics card takes in one piece (a webtoon
/// chapter as one long image) are shown as a column of tiles.
library;

import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/widgets.dart';

/// Pictures with a side longer than this are shown in tiles.
const maxTextureSide = 8192;

/// Height of one tile.
const _tileRows = 4096;

bool needsTiles(Size size) => size.height > maxTextureSide || size.width > maxTextureSide;

/// A picture cut into horizontal tiles, ready to draw.
class ImageTiles {
  ImageTiles._(this.images, this.tops, this.width, this.height);

  final List<ui.Image> images;
  final List<int> tops;
  final int width;
  final int height;

  /// Draws the tiles at their place (page pixels).
  void paint(Canvas canvas, Paint paint) {
    for (final (i, image) in images.indexed) {
      canvas.drawImage(image, Offset(0, tops[i].toDouble()), paint);
    }
  }

  void dispose() {
    for (final i in images) {
      i.dispose();
    }
  }
}

/// RGBA rows of each tile, made in a background isolate.
Future<(int, int, List<TransferableTypedData>)> _decode(String path, bool gray) => Isolate.run(() async {
  final bytes = await File(path).readAsBytes();
  final int w, h;
  final Uint8List rgb;
  if (gray) {
    final g = ImageCodec.decodeGray(bytes);
    (w, h) = (g.width, g.height);
    rgb = Uint8List(w * h * 3);
    for (var i = 0; i < g.data.length; i++) {
      rgb[i * 3] = rgb[i * 3 + 1] = rgb[i * 3 + 2] = g.data[i];
    }
  } else {
    final c = ImageCodec.decode(bytes);
    (w, h) = (c.width, c.height);
    rgb = c.data;
  }
  final tiles = <TransferableTypedData>[];
  for (var top = 0; top < h; top += _tileRows) {
    final rows = (h - top).clamp(0, _tileRows);
    final rgba = Uint8List(w * rows * 4);
    for (var i = 0, j = top * w * 3; i < rgba.length; i += 4, j += 3) {
      rgba[i] = rgb[j];
      rgba[i + 1] = rgb[j + 1];
      rgba[i + 2] = rgb[j + 2];
      rgba[i + 3] = 255;
    }
    tiles.add(TransferableTypedData.fromList([rgba]));
  }
  return (w, h, tiles);
});

/// Reads the picture at [path] (a grayscale mask with [gray]) as tiles.
Future<ImageTiles> loadImageTiles(String path, {bool gray = false}) async {
  final (w, h, tiles) = await _decode(path, gray);
  final images = <ui.Image>[];
  final tops = <int>[];
  for (final (i, t) in tiles.indexed) {
    final rgba = t.materialize().asUint8List();
    final rows = rgba.length ~/ (w * 4);
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(rgba, w, rows, ui.PixelFormat.rgba8888, done.complete);
    images.add(await done.future);
    tops.add(i * _tileRows);
  }
  return ImageTiles._(images, tops, w, h);
}

/// A tall picture shown in tiles, filling its box (the page's size).
class TiledImage extends StatefulWidget {
  const TiledImage({super.key, required this.path});

  final String path;

  @override
  State<TiledImage> createState() => _TiledImageState();
}

class _TiledImageState extends State<TiledImage> {
  ImageTiles? _tiles;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(TiledImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) _load();
  }

  Future<void> _load() async {
    final path = widget.path;
    try {
      final tiles = await loadImageTiles(path);
      if (!mounted || path != widget.path) return tiles.dispose();
      setState(() {
        _tiles?.dispose();
        _tiles = tiles;
      });
    } on Object {
      // An unreadable page shows nothing; the steps report the error.
    }
  }

  @override
  void dispose() {
    _tiles?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _TilesPainter(_tiles));
}

class _TilesPainter extends CustomPainter {
  _TilesPainter(this.tiles);

  final ImageTiles? tiles;

  @override
  void paint(Canvas canvas, Size size) {
    final t = tiles;
    if (t == null) return;
    canvas.save();
    canvas.scale(size.width / t.width, size.height / t.height);
    t.paint(canvas, Paint()..filterQuality = FilterQuality.medium);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TilesPainter old) => old.tiles != tiles;
}
