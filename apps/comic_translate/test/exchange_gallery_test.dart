// Own sheets made by clicking the pieces, and the numbers under the pictures.

import 'package:comic_translate/ui/shell_full/exchange_gallery.dart';
import 'package:ct_core/ct_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('breaks between pieces become own sheets and back', () {
    expect(groupsFromBreaks({4, 6}, 10), '1-4, 5-6, 7-10');
    expect(groupsFromBreaks({9}, 10), '1-9, 10');
    expect(groupsFromBreaks({}, 10), '');
    expect(breaksFromGroups('1-4, 5-6', 10), {4, 6});
    expect(breaksFromGroups('nonsense', 10), isEmpty);
    expect(groupsFromBreaks(breaksFromGroups('1-4, 5-6, 7-10', 10), 10), '1-4, 5-6, 7-10');
  });

  test('the pieces on a sheet by their running numbers', () {
    final items = [
      for (var i = 1; i <= 6; i++)
        ExchangeItem(label: ExchangeLabel(1, i), pageId: 'p', blockIndex: i - 1, box: const BBox(0, 0, 1, 1)),
    ];
    final export = ExchangeExport(
      dir: '',
      mode: ExchangeMode.both,
      items: items,
      prompt: '',
      sheets: const ['sheet_01.png', 'sheet_02.png', 'sheet_03.png'],
      sheetLabels: const {
        'sheet_01.png': ['01-001', '01-002', '01-003', '01-004'],
        'sheet_02.png': ['01-006'],
        'sheet_03.png': ['01-005', '01-002'],
      },
    );
    expect(pieceRange(export, 'sheet_01.png'), '1–4');
    expect(pieceRange(export, 'sheet_02.png'), '6');
    expect(pieceRange(export, 'sheet_03.png'), '2, 5');
    expect(pieceRange(export, 'page_01_context.jpg'), '');
  });
}
