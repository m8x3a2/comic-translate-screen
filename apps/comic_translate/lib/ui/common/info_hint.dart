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

class InfoHint extends StatefulWidget {
  const InfoHint(this.text, {super.key});

  final String text;

  @override
  State<InfoHint> createState() => _InfoHintState();
}

class _InfoHintState extends State<InfoHint> {
  final _tooltip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) => Tooltip(
    key: _tooltip,
    message: widget.text,
    waitDuration: const Duration(milliseconds: 300),
    showDuration: const Duration(seconds: 15),
    constraints: const BoxConstraints(maxWidth: 380),
    // The click is taken here, so a switch or tile around the "i" is not
    // changed by it.
    child: InkResponse(
      onTap: () => _tooltip.currentState?.ensureTooltipVisible(),
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ),
  );
}
