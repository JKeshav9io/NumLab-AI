import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:numlab_frontend/features/explanations/presentation/widgets/explanation_content.dart';

Iterable<TextSpan> spans(TextSpan span) sync* {
  yield span;
  for (final child in span.children ?? <InlineSpan>[]) {
    if (child is TextSpan) yield* spans(child);
  }
}

void main() {
  Future<TextSpan> render(WidgetTester tester, String content) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ExplanationContent(content: content),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(
      find.descendant(
        of: find.byType(ExplanationContent),
        matching: find.byType(Text),
      ),
    );
    return text.textSpan! as TextSpan;
  }

  testWidgets('renders headings, paragraphs, bold, italic, and inline code', (
    tester,
  ) async {
    final codeDelimiter = String.fromCharCode(96);
    final result = await render(
      tester,
      '# Method\n\nA **bold** and *italic* explanation with '
      '${codeDelimiter}x_1$codeDelimiter.',
    );
    expect(
      result.toPlainText(),
      'Method\n\nA bold and italic explanation with x_1.',
    );
    final all = spans(result).toList();
    expect(
      all.any(
        (s) =>
            s.toPlainText() == 'Method' &&
            s.style?.fontWeight == FontWeight.bold &&
            s.style?.fontSize == 21,
      ),
      isTrue,
    );
    expect(
      all.any(
        (s) =>
            s.toPlainText() == 'bold' && s.style?.fontWeight == FontWeight.bold,
      ),
      isTrue,
    );
    expect(
      all.any(
        (s) =>
            s.toPlainText() == 'italic' &&
            s.style?.fontStyle == FontStyle.italic,
      ),
      isTrue,
    );
    expect(
      all.any(
        (s) => s.toPlainText() == 'x_1' && s.style?.fontFamily == 'monospace',
      ),
      isTrue,
    );
    expect(find.byType(SelectionArea), findsOneWidget);
  });

  testWidgets('renders bullet and numbered lists with their start number', (
    tester,
  ) async {
    final result = await render(
      tester,
      '- First **step**\n- Second step\n\n3. Third step\n4. Fourth step',
    );
    expect(result.toPlainText(), contains('• First step\n• Second step'));
    expect(result.toPlainText(), contains('3. Third step\n4. Fourth step'));
  });

  testWidgets('retains nested list content and paragraph boundaries', (
    tester,
  ) async {
    final result = await render(
      tester,
      '- First\n  - Nested\n\nLast paragraph.',
    );
    expect(result.toPlainText(), contains('• First'));
    expect(result.toPlainText(), contains('• Nested'));
    expect(result.toPlainText(), endsWith('\n\nLast paragraph.'));
  });

  testWidgets('renders fenced code literally', (tester) async {
    final result = await render(
      tester,
      '~~~text\n**literal** <script>x()</script>\nx_1 * y\n~~~',
    );
    expect(result.toPlainText(), '**literal** <script>x()</script>\nx_1 * y\n');
    expect(
      spans(result).any((s) => s.style?.fontFamily == 'monospace'),
      isTrue,
    );
  });

  for (final content in ['', ' \n\t ']) {
    testWidgets('empty content "$content" has a readable fallback', (
      tester,
    ) async {
      final result = await render(tester, content);
      expect(result.toPlainText(), 'No explanation text was returned.');
      expect(tester.takeException(), isNull);
    });
  }

  for (final content in [
    '**unfinished emphasis',
    '~~~text\nunfinished code',
    r'\(x_1 * y',
    r'$x_1 * y',
  ]) {
    testWidgets('partially formatted content remains readable: $content', (
      tester,
    ) async {
      final result = await render(tester, content);
      expect(
        result.toPlainText(),
        contains(content.startsWith('~~~') ? 'unfinished code' : content),
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final math in [
    r'$x_1 * y_2 < \alpha$',
    r'\(x_1 * y_2 = \frac{1}{2}\)',
    r'$$\sum_{i=1}^n x_i$$',
    '\\[\n# literal math line\nx_1 * y < 2\n\\]',
  ]) {
    testWidgets('preserves delimited mathematics verbatim: $math', (
      tester,
    ) async {
      final result = await render(tester, '**Result:** $math');
      expect(result.toPlainText(), 'Result: $math');
    });
  }

  testWidgets('HTML and embedded content stay inert text', (tester) async {
    const html =
        '<script>alert("x")</script>\n\n'
        '<iframe src="https://example.com"></iframe>';
    final result = await render(tester, html);
    expect(result.toPlainText(), contains('<script>alert("x")</script>'));
    expect(result.toPlainText(), contains('<iframe src='));
    await render(
      tester,
      '[Click](javascript:alert) ![Chart](https://example.com/image.png)',
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('placeholder-like input does not alter text or mathematics', (
    tester,
  ) async {
    const input =
        '\uE000math0\uE001 '
        r'$x_1*y$';
    final result = await render(tester, input);
    expect(result.toPlainText(), input);
  });

  testWidgets('long paragraphs and code wrap at 320px with accessible text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      final long = List.filled(500, 'x').join();
      final result = await render(
        tester,
        '# Result\n\n$long\n\n~~~text\n$long\n~~~',
      );
      expect(result.toPlainText(), contains(long));
      expect(find.bySemanticsLabel(RegExp('Result')), findsWidgets);
      expect(find.byType(SelectionArea), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });
}
