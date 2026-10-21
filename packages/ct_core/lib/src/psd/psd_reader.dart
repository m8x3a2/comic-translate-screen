/// Reads PSD and PSB files: layers and groups (pixels as 8-bit RGBA), text
/// layers, the merged picture. Grayscale and CMYK become RGB, 16-bit files
/// 8-bit.
library;

import 'dart:io';
import 'dart:typed_data';

import '../image/raster.dart';
import 'packbits.dart';
import 'psd_bytes.dart';
import 'psd_document.dart';
import 'layer_effects.dart';
import 'text_layer.dart';

/// Additional layer data with 8-byte lengths in PSB files.
const _longKeys = {
  'LMsk',
  'Lr16',
  'Lr32',
  'Layr',
  'Mt16',
  'Mt32',
  'Mtrn',
  'Alph',
  'FMsk',
  'lnk2',
  'FEid',
  'FXid',
  'PxSD',
};

/// Additional layer data of adjustment and fill layers.
const _adjustmentKeys = {
  'SoCo',
  'GdFl',
  'PtFl',
  'brit',
  'levl',
  'curv',
  'expA',
  'vibA',
  'hue ',
  'hue2',
  'blnc',
  'blwh',
  'phfl',
  'mixr',
  'clrL',
  'nvrt',
  'post',
  'thrs',
  'grdm',
  'selc',
};

class _Channel {
  _Channel(this.id, this.length);

  final int id;
  final int length;
}

class _RawLayer {
  int top = 0, left = 0, bottom = 0, right = 0;
  final channels = <_Channel>[];
  String blend = 'norm';
  int opacity = 255;
  bool clipping = false;
  bool hidden = false;
  String name = '';
  int? section;
  PsdText? text;
  PsdStroke? stroke;
  bool hasMask = false;
  bool smart = false;
  bool adjustment = false;
  PsdPixels? pixels;
}

class _Header {
  _Header(this.psb, this.channels, this.width, this.height, this.depth, this.mode);

  final bool psb;
  final int channels;
  final int width;
  final int height;
  final int depth;
  final int mode;
}

/// Decodes one channel of [rows] × [width] samples into 8-bit [out].
void _readChannel(PsdReader r, int end, int width, int rows, _Header h, Uint8List out) {
  final bytesPer = h.depth ~/ 8;
  final compression = r.u16();
  final rowBytes = width * bytesPer;
  Uint8List samples;
  switch (compression) {
    case 0:
      samples = r.bytes(rowBytes * rows);
    case 1:
      final counts = [for (var y = 0; y < rows; y++) h.psb ? r.u32() : r.u16()];
      samples = Uint8List(rowBytes * rows);
      for (var y = 0; y < rows; y++) {
        unpackBits(r.data, r.pos, counts[y], samples, y * rowBytes, rowBytes);
        r.skip(counts[y]);
      }
    case 2 || 3:
      samples = Uint8List.fromList(zlib.decode(r.bytes(end - r.pos)));
      if (samples.length < rowBytes * rows) {
        samples = Uint8List(rowBytes * rows)..setRange(0, samples.length, samples);
      }
      if (compression == 3) {
        // Each sample stored as the difference to the one before it.
        if (bytesPer == 1) {
          for (var y = 0; y < rows; y++) {
            for (var x = 1, i = y * rowBytes + 1; x < width; x++, i++) {
              samples[i] = (samples[i] + samples[i - 1]) & 0xFF;
            }
          }
        } else if (bytesPer == 2) {
          final v = ByteData.sublistView(samples);
          for (var y = 0; y < rows; y++) {
            for (var x = 1; x < width; x++) {
              final i = y * rowBytes + x * 2;
              v.setUint16(i, (v.getUint16(i) + v.getUint16(i - 2)) & 0xFFFF);
            }
          }
        }
      }
    default:
      throw PsdFormatException('compression $compression');
  }
  if (bytesPer == 1) {
    out.setRange(0, width * rows, samples);
  } else if (bytesPer == 2) {
    for (var i = 0; i < width * rows; i++) {
      out[i] = samples[i * 2];
    }
  } else {
    final v = ByteData.sublistView(samples);
    for (var i = 0; i < width * rows; i++) {
      out[i] = (v.getFloat32(i * 4).clamp(0.0, 1.0) * 255).round();
    }
  }
}

/// RGBA from colour planes of [h]'s mode (missing alpha: opaque).
Uint8List _toRgba(Map<int, Uint8List> planes, int n, _Header h) {
  final out = Uint8List(n * 4);
  final a = planes[-1];
  if (h.mode == 1 || h.mode == 8) {
    final g = planes[0];
    for (var i = 0; i < n; i++) {
      final v = g?[i] ?? 255;
      out[i * 4] = out[i * 4 + 1] = out[i * 4 + 2] = v;
      out[i * 4 + 3] = a?[i] ?? 255;
    }
  } else if (h.mode == 4) {
    final c = planes[0], m = planes[1], y = planes[2], k = planes[3];
    for (var i = 0; i < n; i++) {
      // Stored inverted: 255 = no ink.
      final kk = k?[i] ?? 255;
      out[i * 4] = (c?[i] ?? 255) * kk ~/ 255;
      out[i * 4 + 1] = (m?[i] ?? 255) * kk ~/ 255;
      out[i * 4 + 2] = (y?[i] ?? 255) * kk ~/ 255;
      out[i * 4 + 3] = a?[i] ?? 255;
    }
  } else {
    final r = planes[0], g = planes[1], b = planes[2];
    for (var i = 0; i < n; i++) {
      out[i * 4] = r?[i] ?? 0;
      out[i * 4 + 1] = g?[i] ?? 0;
      out[i * 4 + 2] = b?[i] ?? 0;
      out[i * 4 + 3] = a?[i] ?? 255;
    }
  }
  return out;
}

_RawLayer _readRecord(PsdReader r, _Header h) {
  final l = _RawLayer()
    ..top = r.i32()
    ..left = r.i32()
    ..bottom = r.i32()
    ..right = r.i32();
  final count = r.u16();
  for (var i = 0; i < count; i++) {
    final id = r.i16();
    l.channels.add(_Channel(id, h.psb ? r.u64() : r.u32()));
  }
  if (r.sig() != '8BIM') throw const PsdFormatException('layer record signature');
  l.blend = r.sig();
  l.opacity = r.u8();
  l.clipping = r.u8() != 0;
  final flags = r.u8();
  l.hidden = flags & 0x02 != 0;
  r.skip(1);
  final extra = r.u32();
  final end = r.pos + extra;
  final mask = r.u32();
  if (mask > 0) {
    final at = r.pos;
    r.skip(16);
    r.u8();
    final maskFlags = r.u8();
    l.hasMask = maskFlags & 0x02 == 0; // not disabled
    r.pos = at + mask;
  }
  r.skip(r.u32()); // blending ranges
  l.name = r.pascal(4);
  while (r.pos + 12 <= end) {
    final s = r.sig();
    if (s != '8BIM' && s != '8B64') break;
    final key = r.sig();
    final len = h.psb && _longKeys.contains(key) ? r.u64() : r.u32();
    final at = r.pos;
    try {
      switch (key) {
        case 'luni':
          final name = r.unicode().replaceAll(RegExp(r'\x00+$'), '');
          if (name.isNotEmpty) l.name = name;
        case 'lsct':
          l.section = r.u32();
        case 'TySh':
          l.text = readTypeTool(r.bytes(len));
        case 'lfx2':
          l.stroke = readStrokeEffect(r.bytes(len));
        case 'SoLd' || 'PlLd' || 'SoLE':
          l.smart = true;
        case final k when _adjustmentKeys.contains(k):
          l.adjustment = true;
      }
    } on Object {
      // A block this program does not understand: skipped.
    }
    r.pos = at + len;
  }
  r.pos = end;
  return l;
}

/// Image resources by id.
Map<int, Uint8List> _readResources(PsdReader r, int end) {
  final out = <int, Uint8List>{};
  while (r.pos + 12 <= end) {
    if (r.sig() != '8BIM') break;
    final id = r.u16();
    r.pascal(2);
    final n = r.u32();
    out[id] = Uint8List.fromList(r.bytes(n));
    if (n.isOdd) r.skip(1);
  }
  r.pos = end;
  return out;
}

/// Reads [bytes] of a PSD or PSB file.
PsdDocument decodePsd(Uint8List bytes) {
  final r = PsdReader(bytes);
  if (r.sig() != '8BPS') throw const PsdFormatException('not a Photoshop file');
  final version = r.u16();
  if (version != 1 && version != 2) throw PsdFormatException('version $version');
  r.skip(6);
  final channels = r.u16(), height = r.u32(), width = r.u32(), depth = r.u16(), mode = r.u16();
  final head = _Header(version == 2, channels, width, height, depth, mode);
  if (!const {1, 8, 16, 32}.contains(depth) || depth == 1) throw PsdFormatException('$depth bits per channel');
  if (!const {1, 3, 4, 8}.contains(mode)) throw PsdFormatException('colour mode $mode');
  r.skip(r.u32());
  final resLength = r.u32();
  final resources = _readResources(r, r.pos + resLength);

  final lmLength = head.psb ? r.u64() : r.u32();
  final lmEnd = r.pos + lmLength;
  final raw = <_RawLayer>[];
  if (lmLength > 0) {
    final liLength = head.psb ? r.u64() : r.u32();
    final liEnd = r.pos + liLength;
    if (liLength > 0) {
      final count = r.i16().abs();
      for (var i = 0; i < count; i++) {
        raw.add(_readRecord(r, head));
      }
      for (final l in raw) {
        final w = l.right - l.left, hh = l.bottom - l.top;
        final planes = <int, Uint8List>{};
        for (final c in l.channels) {
          final end = r.pos + c.length;
          if (w > 0 && hh > 0 && c.id >= -1 && c.length >= 2) {
            final out = Uint8List(w * hh);
            try {
              _readChannel(r, end, w, hh, head, out);
              planes[c.id] = out;
            } on PsdFormatException {
              // A channel that cannot be read stays empty.
            }
          }
          r.pos = end;
        }
        if (w > 0 && hh > 0 && planes.isNotEmpty) {
          l.pixels = PsdPixels(l.left, l.top, w, hh, _toRgba(planes, w * hh, head));
        }
      }
    }
    r.pos = liEnd;
  }
  r.pos = lmEnd;

  RgbImage? composite;
  if (r.pos + 2 <= bytes.length) {
    try {
      composite = _readComposite(r, head);
    } on PsdFormatException {
      composite = null;
    }
  }
  return PsdDocument(width: width, height: height, layers: _tree(raw), composite: composite, resources: resources);
}

RgbImage? _readComposite(PsdReader r, _Header h) {
  final n = h.width * h.height;
  final compression = r.u16();
  final planes = <int, Uint8List>{};
  final colours = switch (h.mode) {
    1 || 8 => 1,
    4 => 4,
    _ => 3,
  };
  final bytesPer = h.depth ~/ 8;
  if (compression == 1) {
    final total = h.channels * h.height;
    final counts = [for (var i = 0; i < total; i++) h.psb ? r.u32() : r.u16()];
    for (var c = 0; c < colours && c < h.channels; c++) {
      final samples = Uint8List(h.width * h.height * bytesPer);
      for (var y = 0; y < h.height; y++) {
        final k = counts[c * h.height + y];
        unpackBits(r.data, r.pos, k, samples, y * h.width * bytesPer, h.width * bytesPer);
        r.skip(k);
      }
      planes[c] = _eight(samples, n, bytesPer);
    }
  } else if (compression == 0) {
    for (var c = 0; c < colours && c < h.channels; c++) {
      planes[c] = _eight(r.bytes(n * bytesPer), n, bytesPer);
    }
  } else {
    return null;
  }
  final rgba = _toRgba(planes, n, h);
  final rgb = Uint8List(n * 3);
  for (var i = 0; i < n; i++) {
    rgb[i * 3] = rgba[i * 4];
    rgb[i * 3 + 1] = rgba[i * 4 + 1];
    rgb[i * 3 + 2] = rgba[i * 4 + 2];
  }
  return RgbImage(h.width, h.height, rgb);
}

Uint8List _eight(Uint8List samples, int n, int bytesPer) {
  if (bytesPer == 1) return samples;
  final out = Uint8List(n);
  if (bytesPer == 2) {
    for (var i = 0; i < n; i++) {
      out[i] = samples[i * 2];
    }
  } else {
    final v = ByteData.sublistView(samples);
    for (var i = 0; i < n; i++) {
      out[i] = (v.getFloat32(i * 4).clamp(0.0, 1.0) * 255).round();
    }
  }
  return out;
}

/// Bottom-to-top records → top-to-bottom tree.
List<PsdNode> _tree(List<_RawLayer> raw) {
  final stack = <List<PsdNode>>[[]];
  for (final l in raw) {
    switch (l.section) {
      case 3:
        stack.add([]);
      case 1 || 2:
        final children = stack.length > 1 ? stack.removeLast() : <PsdNode>[];
        stack.last.add(PsdGroup(l.name, children.reversed.toList(), hidden: l.hidden, open: l.section == 1));
      default:
        stack.last.add(
          PsdLayer(
            l.name,
            pixels: l.pixels,
            text: l.text,
            stroke: l.stroke,
            hidden: l.hidden,
            opacity: l.opacity,
            blendMode: l.blend,
            clipping: l.clipping,
            hasMask: l.hasMask,
            isSmartObject: l.smart,
            isAdjustment: l.adjustment,
          ),
        );
    }
  }
  while (stack.length > 1) {
    final open = stack.removeLast();
    stack.last.addAll(open);
  }
  return stack.single.reversed.toList();
}

Future<PsdDocument> readPsdFile(String path) async => decodePsd(await File(path).readAsBytes());
