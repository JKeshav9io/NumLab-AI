import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:numlab_frontend/core/theme/app_typography.dart';

/// Selectable Markdown text. HTML, links, images, and code are never executed.
///
/// Delimited mathematics is kept verbatim: no math typesetter is installed.
class ExplanationContent extends StatelessWidget {
  const ExplanationContent({required this.content, super.key});

  final String content;

  @override
  Widget build(BuildContext context) {
    final renderer = _ExplanationTextRenderer(content);
    return SelectionArea(
      child: Text.rich(
        TextSpan(children: renderer.render()),
        style: AppTypography.bodyMedium,
        softWrap: true,
      ),
    );
  }
}

class _ExplanationTextRenderer {
  _ExplanationTextRenderer(this.content);

  final String content;
  final List<String> _math = [];
  String _prefix = '\uE000math';

  List<InlineSpan> render() {
    if (content.trim().isEmpty) {
      return [const TextSpan(text: 'No explanation text was returned.')];
    }
    // Use collision-free placeholders before block parsing so Markdown cannot
    // change operators, underscores, backslashes, or lines inside mathematics.
    var marker = 0;
    while (content.contains(_prefix)) {
      marker++;
      _prefix = '\uE000math$marker';
    }
    final protected = content.replaceAllMapped(
      RegExp(
        r'(?<!\\)(\$\$[\s\S]*?(?:\$\$|$)|\$(?!\$)[^\n$]*(?:\$|(?=\n)|$)|\\\[[\s\S]*?(?:\\\]|$)|\\\([\s\S]*?(?:\\\)|$))',
      ),
      (match) {
        final token = '$_prefix${_math.length}\uE001';
        _math.add(match[0]!);
        return token;
      },
    );
    final nodes = md.Document(
      extensionSet: md.ExtensionSet.commonMark,
      // These nodes become Flutter text, never HTML output or a WebView.
      encodeHtml: false,
    ).parseLines(protected.split('\n'));
    return _blocks(nodes);
  }

  String _restore(String text) => text.replaceAllMapped(
    RegExp(RegExp.escape(_prefix) + r'(\d+)' + '\uE001'),
    (match) => _math[int.parse(match[1]!)],
  );

  List<InlineSpan> _blocks(List<md.Node> nodes) => [
    for (var index = 0; index < nodes.length; index++) ...[
      if (index > 0) const TextSpan(text: '\n\n'),
      _span(nodes[index]),
    ],
  ];

  InlineSpan _span(md.Node node) {
    if (node is md.Text) return TextSpan(text: _restore(node.text));
    final element = node as md.Element;
    final children = element.children ?? [];
    switch (element.tag) {
      case 'ul':
      case 'ol':
        final start = int.tryParse(element.attributes['start'] ?? '') ?? 1;
        return TextSpan(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0) const TextSpan(text: '\n'),
              TextSpan(
                text: element.tag == 'ol' ? '${start + index}. ' : '• ',
              ),
              _span(children[index]),
            ],
          ],
        );
      case 'li':
        return TextSpan(
          children: [
            for (var index = 0; index < children.length; index++) ...[
              if (index > 0 &&
                  children[index] is md.Element &&
                  const {'p', 'ul', 'ol', 'pre', 'blockquote'}.contains(
                    (children[index] as md.Element).tag,
                  ))
                const TextSpan(text: '\n\n'),
              _span(children[index]),
            ],
          ],
        );
      case 'blockquote':
        return TextSpan(children: _blocks(children));
      case 'pre':
        return TextSpan(
          text: _restore(element.textContent),
          style: const TextStyle(fontFamily: 'monospace'),
        );
      case 'code':
        return TextSpan(
          text: _restore(element.textContent),
          style: const TextStyle(fontFamily: 'monospace'),
        );
      case 'br':
        return const TextSpan(text: '\n');
      case 'hr':
        return const TextSpan(text: '—');
      case 'img':
        return TextSpan(text: _restore(element.attributes['alt'] ?? ''));
      default:
        final heading = RegExp(r'^h([1-6])$').firstMatch(element.tag);
        final style = heading != null
            ? TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22.0 - int.parse(heading[1]!),
              )
            : switch (element.tag) {
                'strong' => const TextStyle(fontWeight: FontWeight.bold),
                'em' => const TextStyle(fontStyle: FontStyle.italic),
                _ => null,
              };
        return TextSpan(
          style: style,
          children: children.map(_span).toList(),
        );
    }
  }
}
