/// A small "i" with a short explanation, shown on hover and on a click or
/// tap (phones have no hover).
library;

import 'package:flutter/material.dart';

/// [field] with an [InfoHint] after it; just [field] when [info] is empty.
Widget withInfo(Widget field, String? info) => info == null || info.isEmpty
    ? field
    : Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: field),
          Padding(padding: const EdgeInsets.only(left: 4, top: 14), child: InfoHint(info)),
        ],
      );

/// A title (of a switch, a group) with an [InfoHint] right after it.
Widget titleWithInfo(String title, String? info, {TextStyle? style}) => info == null || info.isEmpty
    ? Text(title, style: style)
    : Row(
        children: [
          Flexible(child: Text(title, style: style)),
          InfoHint(info),
        ],
      );

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
