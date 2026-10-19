/// A small "i" with a short explanation, shown on hover and on a click or
/// tap (phones have no hover).
library;

import 'package:flutter/material.dart';

class InfoHint extends StatelessWidget {
  const InfoHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: text,
    triggerMode: TooltipTriggerMode.tap,
    waitDuration: const Duration(milliseconds: 300),
    showDuration: const Duration(seconds: 15),
    constraints: const BoxConstraints(maxWidth: 380),
    child: Semantics(
      button: true,
      label: text,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}
