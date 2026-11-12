/// "Fit to letters" from the page and from the tool bar: runs the fitting
/// and says what came of it.
library;

import 'package:ct_core/ct_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/editor.dart';
import '../../state/steps.dart';
import '../common/labels.dart';
import 'batch_dialogs.dart';

/// Fits the pieces of the current page's mask at [seeds] (none: every
/// piece) with the margin of the tool; the picks are dropped after.
Future<void> runFitMask(BuildContext context, WidgetRef ref, List<Point2> seeds) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final ui = DialogBatchUi(context);
  // Taken before the wait: the button may be gone by then.
  final editor = ref.read(editorProvider.notifier);
  final steps = ref.read(stepsProvider.notifier);
  final result = await steps.fitMask(ui, seeds, margin: ref.read(editorProvider).fitMargin);
  if (result == null) return;
  editor.clearFitPicks();
  final text = result.fitted == 0 && result.empty == 0
      ? l.fitNoPiece
      : result.empty > 0
      ? l.fitNoLetters(result.empty)
      : seeds.length == 1
      ? null
      : l.fitDone(result.fitted);
  if (text == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 4)));
}
