/// Hand-drawn changes to the text-removal mask (the original's brush and
/// eraser paths in `drawing_manager.py`).
library;

import '../model/geometry.dart';

/// One brush or eraser stroke, in page pixels. Strokes apply in order over
/// the generated mask: the brush adds to it, the eraser removes from it.
class MaskStroke {
  const MaskStroke({required this.points, required this.width, this.erase = false});

  final List<Point2> points;

  /// Brush diameter in page pixels.
  final double width;
  final bool erase;

  Map<String, Object?> toJson() => {
    'points': [for (final p in points) p.toJson()],
    'width': width,
    if (erase) 'erase': true,
  };

  factory MaskStroke.fromJson(Map<String, Object?> j) => MaskStroke(
    points: [for (final p in (j['points'] as List? ?? const [])) Point2.fromJson(p)],
    width: (j['width'] as num?)?.toDouble() ?? 1,
    erase: j['erase'] == true,
  );
}
