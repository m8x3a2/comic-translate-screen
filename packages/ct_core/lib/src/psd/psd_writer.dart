/// Writes a [PsdDocument] as a PSD file (PSB when larger than 30 000 px),
/// following Adobe's file format specification.
library;

import 'dart:io';
import 'dart:typed_data';

import 'packbits.dart';
import 'psd_bytes.dart';
import 'psd_document.dart';
import 'layer_effects.dart';
import 'text_layer.dart';

/// One layer record as stored: bottom to top, groups as a closing divider,
/// their layers, then the group itself.
class _Record {
  _Record(
    this.name, {
    this.pixels,
    this.text,
    this.stroke,
    this.hidden = false,
    this.opacity = 255,
    this.blend = 'norm',
    this.section,
  });

  final String name;
  final PsdPixels? pixels;
  final PsdText? text;
  final PsdStroke? stroke;
  final bool hidden;
  final int opacity;
  final String blend;

  /// `lsct`: 1 open group, 2 closed group, 3 the group's end.
  final int? section;
}

List<_Record> _records(List<PsdNode> topToBottom) {
  final out = <_Record>[];
  for (final n in topToBottom.reversed) {
    switch (n) {
      case PsdLayer():
        out.add(
          _Record(
            n.name,
            pixels: n.pixels,
            text: n.text,
            stroke: n.stroke,
            hidden: n.hidden,
            opacity: n.opacity,
            blend: n.blendMode,
          ),
        );
      case PsdGroup():
        out
          ..add(_Record('</Layer group>', section: 3))
          ..addAll(_records(n.children))
          ..add(_Record(n.name, hidden: n.hidden, blend: 'pass', section: n.open ? 1 : 2));
    }
  }
  return out;
}

/// RLE data of one channel ([plane] 0–3 = R, G, B, A of [rgba]).
Uint8List _rleChannel(Uint8List rgba, int width, int height, int plane, int stride, {required bool psb}) {
  final row = Uint8List(width);
  final packed = Uint8List(width + width ~/ 128 + 2);
  final counts = PsdWriter(height * (psb ? 4 : 2));
  final body = PsdWriter(width * height ~/ 2 + 64);
  for (var y = 0; y < height; y++) {
    for (var x = 0, i = y * width * stride + plane; x < width; x++, i += stride) {
      row[x] = rgba[i];
    }
    final n = packBits(row, 0, width, packed, 0);
    psb ? counts.u32(n) : counts.u16(n);
    body.bytes(Uint8List.sublistView(packed, 0, n));
  }
  final c = counts.takeBytes(), b = body.takeBytes();
  return Uint8List(c.length + b.length)
    ..setRange(0, c.length, c)
    ..setRange(c.length, c.length + b.length, b);
}

void _resource(PsdWriter w, int id, List<int> data, {String name = ''}) {
  w.sig('8BIM');
  w.u16(id);
  w.pascal(name, 2);
  w.u32(data.length);
  w.bytes(data);
  if (data.length.isOdd) w.u8(0);
}

void _info(PsdWriter w, String key, void Function() body, {int pad = 2}) {
  w.sig('8BIM');
  w.sig(key);
  w.section(body, pad: pad);
}

/// The file's bytes.
Uint8List encodePsd(PsdDocument doc) {
  final psb = doc.large;
  if (doc.composite case final c? when c.width != doc.width || c.height != doc.height) {
    throw ArgumentError('the merged picture is ${c.width}x${c.height}, the document ${doc.width}x${doc.height}');
  }
  final w = PsdWriter(1 << 20);
  w.sig('8BPS');
  w.u16(psb ? 2 : 1);
  w.zeros(6);
  w.u16(3);
  w.u32(doc.height);
  w.u32(doc.width);
  w.u16(8);
  w.u16(3); // RGB
  w.u32(0); // no colour mode data

  w.section(() {
    // 72 dpi: text sizes in points equal pixels.
    final res = PsdWriter(16)
      ..u32(72 << 16)
      ..u16(1)
      ..u16(1)
      ..u32(72 << 16)
      ..u16(1)
      ..u16(1);
    _resource(w, 0x03ED, res.takeBytes());
    final version = PsdWriter(64)
      ..u32(1)
      ..u8(doc.composite != null ? 1 : 0)
      ..unicode('Adobe Photoshop')
      ..unicode('Comic Translate Screen')
      ..u32(1);
    _resource(w, 0x0421, version.takeBytes());
    for (final MapEntry(:key, :value) in doc.resources.entries) {
      _resource(w, key, value);
    }
  });

  final records = _records(doc.layers);
  w.section(
    () {
      w.section(
        () {
          w.i16(records.length);
          final channels = <List<Uint8List>>[];
          for (final r in records) {
            final px = r.pixels;
            final List<Uint8List> data;
            if (px == null || px.isEmpty) {
              data = [for (var c = 0; c < 4; c++) Uint8List(0)];
            } else {
              data = [
                _rleChannel(px.rgba, px.width, px.height, 3, 4, psb: psb),
                for (var c = 0; c < 3; c++) _rleChannel(px.rgba, px.width, px.height, c, 4, psb: psb),
              ];
            }
            channels.add(data);
            final empty = px == null || px.isEmpty;
            w.i32(empty ? 0 : px.top);
            w.i32(empty ? 0 : px.left);
            w.i32(empty ? 0 : px.top + px.height);
            w.i32(empty ? 0 : px.left + px.width);
            w.u16(4);
            for (final (i, id) in const [-1, 0, 1, 2].indexed) {
              w.i16(id);
              final length = 2 + data[i].length;
              psb ? w.u64(length) : w.u32(length);
            }
            w.sig('8BIM');
            w.sig(r.blend);
            w.u8(r.opacity);
            w.u8(0);
            var flags = 0x08;
            if (r.hidden) flags |= 0x02;
            if (r.section != null) flags |= 0x10;
            w.u8(flags);
            w.u8(0);
            w.section(() {
              w.u32(0); // no mask
              w.u32(0); // no blending ranges
              w.pascal(r.name, 4);
              _info(w, 'luni', () => w.unicode(r.name), pad: 4);
              if (r.section case final s?) {
                _info(w, 'lsct', () {
                  w.u32(s);
                  if (s != 3) {
                    w.sig('8BIM');
                    w.sig('pass');
                  }
                });
              }
              if (r.text case final t?) _info(w, 'TySh', () => writeTypeTool(w, t));
              if (r.stroke case final s?) _info(w, 'lfx2', () => writeStrokeEffect(w, s));
            });
          }
          for (final data in channels) {
            for (final d in data) {
              w.u16(d.isEmpty ? 0 : 1);
              w.bytes(d);
            }
          }
        },
        pad: 4,
        long: psb,
      );
      w.u32(0); // no global layer mask
    },
    pad: 2,
    long: psb,
  );

  // The merged picture: what viewers show.
  final composite = doc.composite;
  w.u16(1);
  if (composite == null) {
    final blank = Uint8List(doc.width * 3)..fillRange(0, doc.width * 3, 255);
    final rows = [for (var c = 0; c < 3; c++) _rleChannel(blank, doc.width, 1, c, 3, psb: psb)];
    final countBytes = psb ? 4 : 2;
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < doc.height; y++) {
        w.bytes(Uint8List.sublistView(rows[c], 0, countBytes));
      }
    }
    for (var c = 0; c < 3; c++) {
      for (var y = 0; y < doc.height; y++) {
        w.bytes(Uint8List.sublistView(rows[c], countBytes));
      }
    }
  } else {
    final planes = [
      for (var c = 0; c < 3; c++) _rleChannel(composite.data, composite.width, composite.height, c, 3, psb: psb),
    ];
    final countBytes = composite.height * (psb ? 4 : 2);
    for (final p in planes) {
      w.bytes(Uint8List.sublistView(p, 0, countBytes));
    }
    for (final p in planes) {
      w.bytes(Uint8List.sublistView(p, countBytes));
    }
  }
  return w.takeBytes();
}

/// Writes [doc] to [path].
Future<void> writePsdFile(String path, PsdDocument doc) async {
  await File(path).writeAsBytes(encodePsd(doc), flush: true);
}
