/// Layer styles (`lfx2`): only "Stroke", outside, one colour — the outline
/// of the translated text (key set as Photoshop and ag-psd, MIT, write it).
library;

import 'dart:typed_data';

import 'descriptor.dart';
import 'psd_bytes.dart';
import 'psd_document.dart';

void writeStrokeEffect(PsdWriter w, PsdStroke s) {
  w.u32(0);
  writeVersionedDescriptor(
    w,
    Descriptor('null', {
      'Scl ': const DescUnit('#Prc', 100),
      'masterFXSwitch': true,
      'FrFX': Descriptor('FrFX', {
        'enab': true,
        'present': true,
        'showInDialog': true,
        'Styl': const DescEnum('FStl', 'OutF'),
        'PntT': const DescEnum('FrFl', 'SClr'),
        'Md  ': const DescEnum('BlnM', 'Nrml'),
        'Opct': DescUnit('#Prc', ((s.color >>> 24) & 0xFF) / 255 * 100),
        'Sz  ': DescUnit('#Pxl', s.size.roundToDouble().clamp(1, 250)),
        'Clr ': Descriptor('RGBC', {
          'Rd  ': ((s.color >> 16) & 0xFF).toDouble(),
          'Grn ': ((s.color >> 8) & 0xFF).toDouble(),
          'Bl  ': (s.color & 0xFF).toDouble(),
        }),
        'overprint': false,
      }),
    }),
  );
}

double? _value(Object? v) => switch (v) {
  DescUnit(:final value) => value,
  final num n => n.toDouble(),
  _ => null,
};

/// The stroke of an `lfx2` block, when it has one switched on.
PsdStroke? readStrokeEffect(Uint8List data) {
  final r = PsdReader(data);
  if (r.u32() != 0) return null;
  final d = readVersionedDescriptor(r);
  if (d['masterFXSwitch'] == false) return null;
  Object? fx = d['FrFX'];
  if (d['frameFXMulti'] case final List list) {
    fx = list.whereType<Descriptor>().where((x) => x['enab'] == true).firstOrNull;
  }
  if (fx is! Descriptor || fx['enab'] != true) return null;
  final size = _value(fx['Sz  ']) ?? 0;
  if (size <= 0) return null;
  final c = fx['Clr '];
  int ch(String k) => c is Descriptor ? (_value(c[k]) ?? 0).round().clamp(0, 255) : 0;
  final alpha = ((_value(fx['Opct']) ?? 100) / 100 * 255).round().clamp(0, 255);
  return PsdStroke(alpha << 24 | ch('Rd  ') << 16 | ch('Grn ') << 8 | ch('Bl  '), size);
}
