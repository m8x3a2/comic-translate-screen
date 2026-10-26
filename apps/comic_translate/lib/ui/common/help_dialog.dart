/// Help pages (the owner's idea): markdown files bundled with the app
/// (`assets/help/<topic>.<language>.md`), shown inside it with the
/// contents on the side, opened in another app or saved elsewhere.
/// Not in the original.
library;

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../state/app_state.dart';
import 'labels.dart';

enum HelpTopic { exchange }

/// The help languages there are; others get the English one.
const helpLanguages = {'en', 'ru'};

String helpAsset(HelpTopic topic, String language) =>
    'assets/help/${topic.name}.${helpLanguages.contains(language) ? language : 'en'}.md';

Future<void> showHelp(BuildContext context, HelpTopic topic) => showDialog<void>(
  context: context,
  builder: (_) => _HelpDialog(topic: topic),
);

/// A help page cut at its `## ` headings: the part before the first one
/// (the title) and one part per heading.
class HelpSection {
  const HelpSection(this.title, this.text);

  /// Empty for the part before the first heading.
  final String title;

  /// The markdown of the part, its heading included.
  final String text;
}

List<HelpSection> helpSections(String markdown) {
  final sections = <HelpSection>[];
  var title = '';
  final lines = <String>[];
  void close() {
    final text = lines.join('\n').trim();
    if (text.isNotEmpty || title.isNotEmpty) sections.add(HelpSection(title, text));
    lines.clear();
  }

  for (final line in markdown.replaceAll('\r\n', '\n').split('\n')) {
    if (line.startsWith('## ')) {
      close();
      title = line.substring(3).trim();
    }
    lines.add(line);
  }
  close();
  return sections;
}

class _HelpDialog extends ConsumerStatefulWidget {
  const _HelpDialog({required this.topic});

  final HelpTopic topic;

  @override
  ConsumerState<_HelpDialog> createState() => _HelpDialogState();
}

class _HelpDialogState extends ConsumerState<_HelpDialog> {
  String? _text;
  late String _asset;
  final _keys = <GlobalKey>[];
  String? _note;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final asset = helpAsset(widget.topic, Localizations.localeOf(context).languageCode);
    if (_text != null && asset == _asset) return;
    _asset = asset;
    rootBundle.loadString(asset).then((text) {
      if (mounted) setState(() => _text = text);
    });
  }

  String get _fileName => p.basename(_asset);

  /// A copy in the data folder: another app opens that one.
  Future<void> _openElsewhere() async {
    final l = context.l10n;
    final dir = Directory(p.join(ref.read(servicesProvider).paths.root.path, 'help'))..createSync(recursive: true);
    final file = File(p.join(dir.path, _fileName));
    String? error;
    try {
      await file.writeAsString(_text!);
      if (!await launchUrl(Uri.file(file.path))) error = file.path;
    } on Object catch (e) {
      error = '$e';
    }
    if (mounted && error != null) setState(() => _note = l.helpOpenFailed(error!));
  }

  Future<void> _saveAs() async {
    final l = context.l10n;
    final place = await getSaveLocation(
      suggestedName: _fileName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'md', extensions: ['md']),
      ],
    );
    if (place == null) return;
    await File(place.path).writeAsString(_text!);
    if (mounted) setState(() => _note = l.helpSaved(place.path));
  }

  void _go(int i) {
    final target = _keys[i].currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final text = _text;
    final sections = text == null ? const <HelpSection>[] : helpSections(text);
    while (_keys.length < sections.length) {
      _keys.add(GlobalKey());
    }
    final style = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
      listBullet: theme.textTheme.bodyMedium,
      code: theme.textTheme.bodyMedium?.copyWith(
        fontFamily: 'Consolas',
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
      ),
      h2Padding: const EdgeInsets.only(top: 12),
    );
    // All of it built (a page is short): the contents scroll to parts far
    // below, which a lazy list would not have yet.
    final page = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, s) in sections.indexed)
            MarkdownBody(
              key: _keys[i],
              data: s.text,
              selectable: true,
              styleSheet: style,
              onTapLink: (_, href, _) {
                if (href != null && href.startsWith('https://')) launchUrl(Uri.parse(href));
              },
            ),
        ],
      ),
    );
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 860),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.help_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.helpTitle, style: theme.textTheme.titleLarge)),
                  IconButton(tooltip: l.close, onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: text == null
                    ? const Center(child: CircularProgressIndicator())
                    : LayoutBuilder(
                        builder: (context, c) => c.maxWidth < 760
                            ? page
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 250,
                                    child: ListView(
                                      children: [
                                        for (final (i, s) in sections.indexed)
                                          if (s.title.isNotEmpty)
                                            ListTile(
                                              dense: true,
                                              visualDensity: VisualDensity.compact,
                                              title: Text(s.title.replaceAll('*', '')),
                                              onTap: () => _go(i),
                                            ),
                                      ],
                                    ),
                                  ),
                                  const VerticalDivider(width: 24),
                                  Expanded(child: page),
                                ],
                              ),
                      ),
              ),
              if (_note != null) ...[
                const SizedBox(height: 8),
                SelectableText(_note!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: text == null ? null : _openElsewhere,
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l.helpOpenElsewhere),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: text == null ? null : _saveAs,
                    icon: const Icon(Icons.save_alt),
                    label: Text(l.saveAs),
                  ),
                  const Spacer(),
                  FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.close)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
