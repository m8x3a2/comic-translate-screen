// Port of modules/detection/heuristic_lines/direction.py (the functions the
// pipeline uses).
part of '../heuristic_lines.dart';

List<HLine> _sortLines(List<HLine> lines, String direction) {
  if (direction == _vertical) {
    return _sorted(lines, (line) {
      final b = line.axisBox;
      return [-b[0], b[1]];
    });
  }
  return _sorted(lines, (line) {
    final b = line.axisBox;
    return [b[1], b[0]];
  });
}

String _fallbackDirection(List<int> box, String sourceLanguage) {
  final width = math.max(1, box[2] - box[0]);
  final height = math.max(1, box[3] - box[1]);
  final aspectDirection = height > width * 1.15 ? _vertical : _horizontal;

  final normalized = _normalizeSourceLanguage(sourceLanguage);
  if (normalized == 'ko') return _horizontal;
  if ((normalized == 'ja' || normalized == 'zh') && 0.85 <= height / width && height / width <= 1.15) {
    return height >= width * 0.9 ? _vertical : _horizontal;
  }
  return aspectDirection;
}

String _normalizeSourceLanguage(String sourceLanguage) {
  final value = sourceLanguage.trim().toLowerCase();
  if (value == 'ja' || value == 'japanese') return 'ja';
  if (value == 'ko' || value == 'korean') return 'ko';
  if (value == 'zh' || value == 'ch' || value.startsWith('zh-') || value.contains('chinese')) return 'zh';
  return 'other';
}
