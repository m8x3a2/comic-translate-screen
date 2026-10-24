/// "Pages: 1,5-8,10" (the owner's idea): picks pages by their numbers for
/// the steps, the chat, the export and "Translate selected". While it is not
/// being typed in, it shows the pages picked now.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/workspace.dart';
import '../common/labels.dart';

class PageNumbersField extends ConsumerStatefulWidget {
  const PageNumbersField({super.key, this.enabled = true, this.dense = true});

  final bool enabled;

  /// Narrow: the label goes inside the field as a hint.
  final bool dense;

  @override
  ConsumerState<PageNumbersField> createState() => _PageNumbersFieldState();
}

class _PageNumbersFieldState extends ConsumerState<PageNumbersField> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  /// The part that is not a page, after Enter.
  String? _wrong;

  /// The picked pages as numbers.
  static String _numbers(WorkspaceState ws) {
    final ids = ws.pickedPageIds;
    return pageNumbersText([
      for (final (i, page) in ws.pages.indexed)
        if (ids.contains(page.id)) i,
    ]);
  }

  @override
  void initState() {
    super.initState();
    _text.text = _numbers(ref.read(workspaceProvider));
    _focus.addListener(
      () => setState(() {
        if (_focus.hasFocus) return;
        _wrong = null;
        _text.text = _numbers(ref.read(workspaceProvider));
      }),
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _pick() {
    final ws = ref.read(workspaceProvider);
    try {
      final picked = parsePageNumbers(_text.text, ws.pages.length);
      if (picked.isEmpty) return;
      ref.read(workspaceProvider.notifier).pickPages(picked);
      setState(() => _wrong = null);
      _focus.unfocus();
    } on FormatException catch (e) {
      setState(() => _wrong = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final ws = ref.watch(workspaceProvider);
    // Shows the picked pages unless the user is typing.
    ref.listen(workspaceProvider.select(_numbers), (_, now) {
      if (!_focus.hasFocus) _text.text = now;
    });
    return Tooltip(
      message: l.pageNumbersTip,
      waitDuration: const Duration(milliseconds: 600),
      child: TextField(
        controller: _text,
        focusNode: _focus,
        enabled: widget.enabled && ws.pages.length > 1,
        style: Theme.of(context).textTheme.bodySmall,
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.checklist, size: 18),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          labelText: widget.dense ? null : l.pageNumbers,
          hintText: l.pageNumbersHint,
          errorText: _wrong == null ? null : l.pageNumbersWrong(_wrong!, '${ws.pages.length}'),
          errorMaxLines: 3,
          suffixIcon: _focus.hasFocus
              ? IconButton(
                  tooltip: l.pageNumbersPick,
                  visualDensity: VisualDensity.compact,
                  onPressed: _pick,
                  icon: const Icon(Icons.keyboard_return, size: 18),
                )
              : null,
        ),
        onSubmitted: (_) => _pick(),
      ),
    );
  }
}
