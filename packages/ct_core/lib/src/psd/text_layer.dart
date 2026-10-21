/// The `TySh` block of a text layer: transform, text descriptor with
/// EngineData, warp (structure as Photoshop writes it; field set after
/// ag-psd, MIT).
library;

import 'dart:math' as math;
import 'dart:typed_data';

import 'descriptor.dart';
import 'engine_data.dart';
import 'psd_bytes.dart';
import 'psd_document.dart';

const _justification = {PsdJustification.left: 0, PsdJustification.right: 1, PsdJustification.center: 2};

Map<String, Object?> _color(int argb) => {
  'Type': 1,
  'Values': [((argb >> 24) & 0xFF) / 255, ((argb >> 16) & 0xFF) / 255, ((argb >> 8) & 0xFF) / 255, (argb & 0xFF) / 255],
};

int? _argb(Object? c) {
  if (c is! Map) return null;
  final v = c['Values'];
  if (v is! List || v.length < 4) return null;
  int ch(Object? x) => ((x is num ? x.toDouble() : 0.0).clamp(0.0, 1.0) * 255).round();
  return switch (c['Type']) {
    1 => ch(v[0]) << 24 | ch(v[1]) << 16 | ch(v[2]) << 8 | ch(v[3]),
    0 => 0xFF000000 | (0x10101 * (255 - ch(v[1]))),
    _ => null,
  };
}

Map<String, Object?> _paragraph(PsdJustification j) => {
  'Justification': _justification[j],
  'FirstLineIndent': 0.0,
  'StartIndent': 0.0,
  'EndIndent': 0.0,
  'SpaceBefore': 0.0,
  'SpaceAfter': 0.0,
  'AutoHyphenate': false,
  'HyphenatedWordSize': 6,
  'PreHyphen': 2,
  'PostHyphen': 2,
  'ConsecutiveHyphens': 8,
  'Zone': 36.0,
  'WordSpacing': [0.8, 1.0, 1.33],
  'LetterSpacing': [0.0, 0.0, 0.0],
  'GlyphSpacing': [1.0, 1.0, 1.0],
  'AutoLeading': 1.2,
  'LeadingType': 0,
  'Hanging': false,
  'Burasagari': false,
  'KinsokuOrder': 0,
  'EveryLineComposer': false,
};

Map<String, Object?> _style(PsdText t, int font) => {
  'Font': font,
  'FontSize': t.fontSize,
  'FauxBold': t.fauxBold,
  'FauxItalic': t.fauxItalic,
  'AutoLeading': t.leading == null,
  'Leading': t.leading ?? 0.0,
  'HorizontalScale': 1.0,
  'VerticalScale': 1.0,
  'Tracking': 0,
  'AutoKerning': true,
  'Kerning': 0,
  'BaselineShift': 0.0,
  'FontCaps': 0,
  'FontBaseline': 0,
  'Underline': t.underline,
  'Strikethrough': false,
  'Ligatures': true,
  'DLigatures': false,
  'BaselineDirection': 2,
  'Tsume': 0.0,
  'StyleRunAlignment': 2,
  'Language': 0,
  'NoBreak': false,
  'FillColor': _color(t.color),
  'StrokeColor': _color(t.strokeColor ?? 0xFF000000),
  'FillFlag': true,
  'StrokeFlag': t.strokeColor != null && t.strokeWidth > 0,
  // The outline under the letters, as this program draws it.
  'FillFirst': false,
  'YUnderline': 1,
  'OutlineWidth': t.strokeWidth > 0 ? t.strokeWidth : 1.0,
  'CharacterDirection': 0,
  'HindiNumbers': false,
  'Kashida': 1,
  'DiacriticPos': 2,
};

const _kinsoku = [
  {
    'Name': 'PhotoshopKinsokuHard',
    'NoStart': '、。，．・：；？！ー―’”）〕］｝〉》」』】ヽヾゝゞ々ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ゛゜?!)]},.:;℃℉¢％‰',
    'NoEnd': '‘“（〔［｛〈《「『【([{￥＄£＠§〒＃',
    'Keep': '―‥',
    'Hanging': '、。.,',
  },
  {
    'Name': 'PhotoshopKinsokuSoft',
    'NoStart': '、。，．・：；？！’”）〕］｝〉》」』】ヽヾゝゞ々',
    'NoEnd': '‘“（〔［｛〈《「『【',
    'Keep': '―‥',
    'Hanging': '、。.,',
  },
];

/// EngineData of [t].
Map<String, Object?> textEngineData(PsdText t) {
  final text = '${t.text.replaceAll('\r\n', '\n').replaceAll('\n', '\r')}\r';
  final fonts = [
    {'Name': t.font, 'Script': 0, 'FontType': 1, 'Synthetic': 0},
    {'Name': 'AdobeInvisFont', 'Script': 0, 'FontType': 0, 'Synthetic': 0},
  ];
  final paragraphs = <Map<String, Object?>>[];
  final paragraphLengths = <int>[];
  for (var i = 0, last = 0; i < text.length; i++) {
    if (text.codeUnitAt(i) != 13) continue;
    paragraphLengths.add(i - last + 1);
    paragraphs.add({
      'ParagraphSheet': {'DefaultStyleSheet': 0, 'Properties': _paragraph(t.justification)},
      'Adjustments': {
        'Axis': [1.0, 0.0, 1.0],
        'XY': [0.0, 0.0],
      },
    });
    last = i + 1;
  }
  final direction = t.vertical ? 2 : 0;
  final resources = {
    'KinsokuSet': _kinsoku,
    'MojiKumiSet': [
      for (var i = 1; i <= 4; i++) {'InternalName': 'Photoshop6MojiKumiSet$i'},
    ],
    'TheNormalStyleSheet': 0,
    'TheNormalParagraphSheet': 0,
    'ParagraphSheetSet': [
      {'Name': 'Normal RGB', 'DefaultStyleSheet': 0, 'Properties': _paragraph(t.justification)},
    ],
    'StyleSheetSet': [
      {'Name': 'Normal RGB', 'StyleSheetData': _style(t, 0)},
    ],
    'FontSet': fonts,
    'SuperscriptSize': 0.583,
    'SuperscriptPosition': 0.333,
    'SubscriptSize': 0.583,
    'SubscriptPosition': 0.333,
    'SmallCapSize': 0.7,
  };
  return {
    'EngineDict': {
      'Editor': {'Text': text},
      'ParagraphRun': {
        'DefaultRunData': {
          'ParagraphSheet': {'DefaultStyleSheet': 0, 'Properties': <String, Object?>{}},
          'Adjustments': {
            'Axis': [1.0, 0.0, 1.0],
            'XY': [0.0, 0.0],
          },
        },
        'RunArray': paragraphs,
        'RunLengthArray': paragraphLengths,
        'IsJoinable': 1,
      },
      'StyleRun': {
        'DefaultRunData': {
          'StyleSheet': {'StyleSheetData': <String, Object?>{}},
        },
        'RunArray': [
          {
            'StyleSheet': {'StyleSheetData': _style(t, 0)},
          },
        ],
        'RunLengthArray': [text.length],
        'IsJoinable': 2,
      },
      'GridInfo': {
        'GridIsOn': false,
        'ShowGrid': false,
        'GridSize': 18.0,
        'GridLeading': 22.0,
        'GridColor': _color(0xFF0000FF),
        'GridLeadingFillColor': _color(0xFF0000FF),
        'AlignLineHeightToGridFlags': false,
      },
      'AntiAlias': 4,
      'UseFractionalGlyphWidths': true,
      'Rendered': {
        'Version': 1,
        'Shapes': {
          'WritingDirection': direction,
          'Children': [
            {
              'ShapeType': 1,
              'Procession': t.vertical ? 1 : 0,
              'Lines': {'WritingDirection': direction, 'Children': <Object?>[]},
              'Cookie': {
                'Photoshop': {
                  'ShapeType': 1,
                  'BoxBounds': [0.0, 0.0, t.boxWidth, t.boxHeight],
                  'Base': {
                    'ShapeType': 1,
                    'TransformPoint0': [1.0, 0.0],
                    'TransformPoint1': [0.0, 1.0],
                    'TransformPoint2': [0.0, 0.0],
                  },
                },
              },
            },
          ],
        },
      },
    },
    'ResourceDict': resources,
    'DocumentResources': resources,
  };
}

Descriptor _bounds(String classId, double l, double t, double r, double b) => Descriptor(classId, {
  'Left': DescUnit('#Pnt', l),
  'Top ': DescUnit('#Pnt', t),
  'Rght': DescUnit('#Pnt', r),
  'Btom': DescUnit('#Pnt', b),
});

/// The `TySh` block data of [t].
void writeTypeTool(PsdWriter w, PsdText t) {
  w.i16(1);
  for (final v in t.transform) {
    w.f64(v);
  }
  w.i16(50);
  writeVersionedDescriptor(
    w,
    Descriptor('TxLr', {
      'Txt ': t.text.replaceAll('\r\n', '\n').replaceAll('\n', '\r'),
      'textGridding': const DescEnum('textGridding', 'None'),
      'Ornt': DescEnum('Ornt', t.vertical ? 'Vrtc' : 'Hrzn'),
      'AntA': const DescEnum('Annt', 'antiAliasSharp'),
      'bounds': _bounds('bounds', 0, 0, t.boxWidth, t.boxHeight),
      'boundingBox': _bounds('boundingBox', 0, 0, t.boxWidth, t.boxHeight),
      'TextIndex': 0,
      'EngineData': serializeEngineData(textEngineData(t)),
    }),
  );
  w.i16(1);
  writeVersionedDescriptor(
    w,
    Descriptor('warp', {
      'warpStyle': const DescEnum('warpStyle', 'warpNone'),
      'warpValue': 0.0,
      'warpPerspective': 0.0,
      'warpPerspectiveOther': 0.0,
      'warpRotate': const DescEnum('Ornt', 'Hrzn'),
    }),
  );
  w.zeros(16);
}

double _num(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : fallback;

Object? _path(Object? root, List<Object> keys) {
  Object? v = root;
  for (final k in keys) {
    if (k is int) {
      if (v is! List || k >= v.length) return null;
      v = v[k];
    } else {
      if (v is! Map) return null;
      v = v[k];
    }
  }
  return v;
}

/// Reads a `TySh` block (the whole of [data]); null when it is not one this
/// program understands.
PsdText? readTypeTool(Uint8List data) {
  final r = PsdReader(data);
  if (r.i16() != 1) return null;
  final m = [for (var i = 0; i < 6; i++) r.f64()];
  if (r.i16() != 50) return null;
  final d = readVersionedDescriptor(r);
  final txt = d['Txt '];
  var text = (txt is String ? txt : '').replaceAll('\r', '\n');
  final vertical = d['Ornt'] == const DescEnum('Ornt', 'Vrtc');

  Map<String, Object?> engine = const {};
  if (d['EngineData'] case final Uint8List bytes) {
    try {
      engine = parseEngineData(bytes);
    } on FormatException {
      // Text and placement only.
    }
  }
  final editor = _path(engine, ['EngineDict', 'Editor', 'Text']);
  if (editor is String && editor.isNotEmpty) text = editor.replaceAll('\r', '\n');
  while (text.endsWith('\n')) {
    text = text.substring(0, text.length - 1);
  }

  final style = {
    ...?(_path(engine, ['ResourceDict', 'StyleSheetSet', 0, 'StyleSheetData']) as Map?)?.cast<String, Object?>(),
    ...?(_path(engine, ['EngineDict', 'StyleRun', 'RunArray', 0, 'StyleSheet', 'StyleSheetData']) as Map?)
        ?.cast<String, Object?>(),
  };
  final fonts = _path(engine, ['ResourceDict', 'FontSet']);
  var font = '';
  final fontIndex = style['Font'];
  if (fonts is List && fontIndex is int && fontIndex >= 0 && fontIndex < fonts.length) {
    font = '${_path(fonts, [fontIndex, 'Name']) ?? ''}';
  }
  final justification = switch (_path(engine, [
    'EngineDict',
    'ParagraphRun',
    'RunArray',
    0,
    'ParagraphSheet',
    'Properties',
    'Justification',
  ])) {
    1 || 4 => PsdJustification.right,
    2 || 5 => PsdJustification.center,
    _ => PsdJustification.left,
  };

  // Text space → page: sizes grow with the transform's scale.
  final scale = math.sqrt((m[0] * m[3] - m[1] * m[2]).abs());
  final s = scale > 0 ? scale : 1.0;
  var l = 0.0, t = 0.0, rr = 0.0, b = 0.0;
  final box = _path(engine, ['EngineDict', 'Rendered', 'Shapes', 'Children', 0, 'Cookie', 'Photoshop', 'BoxBounds']);
  final bounds = d['bounds'];
  if (box is List && box.length == 4) {
    (l, t, rr, b) = (_num(box[0]), _num(box[1]), _num(box[2]), _num(box[3]));
  } else if (bounds is Descriptor) {
    double u(String k) => switch (bounds[k]) {
      DescUnit(:final value) => value,
      final num v => v.toDouble(),
      _ => 0,
    };
    (l, t, rr, b) = (u('Left'), u('Top '), u('Rght'), u('Btom'));
  }
  // The box's top-left corner on the page, the rest of the transform kept.
  final ox = m[4] + m[0] * l + m[2] * t, oy = m[5] + m[1] * l + m[3] * t;
  final stroke = style['StrokeFlag'] == true;
  final leading = style['AutoLeading'] == false ? _num(style['Leading']) * s : null;
  return PsdText(
    text: text,
    font: font,
    fontSize: _num(style['FontSize'], 12) * s,
    transform: [m[0] / s, m[1] / s, m[2] / s, m[3] / s, ox, oy],
    boxWidth: (rr - l) * s,
    boxHeight: (b - t) * s,
    color: _argb(style['FillColor']) ?? 0xFF000000,
    fauxBold: style['FauxBold'] == true,
    fauxItalic: style['FauxItalic'] == true,
    underline: style['Underline'] == true,
    strokeColor: stroke ? _argb(style['StrokeColor']) ?? 0xFF000000 : null,
    strokeWidth: stroke ? _num(style['OutlineWidth'], 1) * s : 0,
    justification: justification,
    leading: leading != null && leading > 0 ? leading : null,
    vertical: vertical,
  );
}
