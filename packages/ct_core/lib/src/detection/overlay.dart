/// Debug visualisation of detection results (like `visualize_textblocks`
/// and `visualize_speech_bubbles` in the original).
library;

import 'dart:math' as math;

import 'package:dartcv4/dartcv.dart' as cv;

import '../image/cv_bridge.dart';
import '../image/raster.dart';
import '../model/text_block.dart';

/// Draws bubbles (green: text inside, red: free text), text blocks, their
/// lines and indices on a copy of [image].
RgbImage drawDetectionOverlay(RgbImage image, List<TextBlock> blocks) {
  final mat = CvBridge.rgbToMat(image);
  try {
    final lw = math.max(((image.width + image.height + 3) / 2 * 0.003).round(), 2);
    for (final b in blocks) {
      final bubble = b.bubbleXyxy;
      if (bubble != null) {
        final color = b.textClass == TextClass.free ? cv.Scalar(255, 0, 0) : cv.Scalar(0, 255, 0);
        cv.rectangle(mat, cv.Rect(bubble.x1, bubble.y1, bubble.width, bubble.height), color, thickness: lw);
      }
    }
    for (final (i, b) in blocks.indexed) {
      final box = b.xyxy;
      cv.rectangle(mat, cv.Rect(box.x1, box.y1, box.width, box.height), cv.Scalar(127, 255, 127), thickness: lw);
      for (final (j, line) in b.lines.indexed) {
        final polygon = line.polygon;
        if (polygon != null) {
          final pts = cv.VecVecPoint.fromList([
            [for (final p in polygon) cv.Point(p.x.round(), p.y.round())],
          ]);
          cv.polylines(mat, pts, true, cv.Scalar(0, 127, 255), thickness: 2);
          pts.dispose();
          cv.putText(mat, '$j', cv.Point(polygon.first.x.round(), polygon.first.y.round()), cv.FONT_HERSHEY_SIMPLEX, 0.5,
              cv.Scalar(255, 127, 0));
        } else {
          final lb = line.axisBox;
          cv.rectangle(mat, cv.Rect(lb.x1, lb.y1, lb.width, lb.height), cv.Scalar(0, 127, 255), thickness: 2);
          cv.putText(mat, '$j', cv.Point(lb.x1, lb.y1), cv.FONT_HERSHEY_SIMPLEX, 0.5, cv.Scalar(255, 127, 0));
        }
      }
      cv.putText(mat, '$i', cv.Point(box.x1, box.y1 + lw + 12), cv.FONT_HERSHEY_SIMPLEX, 0.7, cv.Scalar(255, 127, 127),
          thickness: 2);
    }
    return CvBridge.matToRgb(mat);
  } finally {
    mat.dispose();
  }
}
