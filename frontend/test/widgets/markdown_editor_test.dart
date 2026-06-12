import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/data/api_client.dart';
import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/markdown_editor.dart';

const _hash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Widget _app(Widget child) {
  return MaterialApp(
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: child),
  );
}

void main() {
  late String lastMarkdown;

  Widget editor({String initial = ''}) {
    lastMarkdown = initial;
    return _app(MarkdownEditor(
      initialMarkdown: initial,
      api: ApiClient('http://127.0.0.1:9'),
      onChanged: (value) => lastMarkdown = value,
    ));
  }

  testWidgets('opens in WYSIWYG mode by default with the toolbar', (tester) async {
    await tester.pumpWidget(editor(initial: 'Hola **mundo**.'));
    await tester.pumpAndSettle();

    // WYSIWYG surface visible, raw source hidden (FR-010).
    expect(find.byType(AppFlowyEditor), findsOneWidget);
    expect(find.byKey(MarkdownEditor.sourceFieldKey), findsNothing);

    // Toolbar actions present, with Spanish tooltips.
    for (final tooltip in [
      'Negrita',
      'Cursiva',
      'Título de sección',
      'Subtítulo',
      'Lista',
      'Insertar tabla',
      'Insertar imagen',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
    // Rendered text, not markdown syntax.
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('source toggle reveals raw markdown and syncs edits back',
      (tester) async {
    await tester.pumpWidget(editor(initial: 'Texto *original* aquí.'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Fuente'));
    await tester.pumpAndSettle();

    final field = find.byKey(MarkdownEditor.sourceFieldKey);
    expect(field, findsOneWidget);
    expect(
      tester.widget<TextField>(field).controller!.text,
      contains('*original*'),
    );

    await tester.enterText(field, 'Texto nuevo con **negrita**.');
    await tester.pumpAndSettle();
    expect(lastMarkdown, 'Texto nuevo con **negrita**.');

    // Back to WYSIWYG: the edit survives the round trip.
    await tester.tap(find.byTooltip('Fuente'));
    await tester.pumpAndSettle();
    expect(find.byType(AppFlowyEditor), findsOneWidget);
    expect(find.textContaining('Texto nuevo con', findRichText: true), findsOneWidget);
  });

  testWidgets('toolbar formatting produces the expected markdown', (tester) async {
    await tester.pumpWidget(editor(initial: 'Hola'));
    await tester.pumpAndSettle();

    final state = tester.state<MarkdownEditorState>(find.byType(MarkdownEditor));
    state.editorState.selection = Selection(
      start: Position(path: [0], offset: 0),
      end: Position(path: [0], offset: 4),
    );
    await state.toggleBold();
    await tester.pumpAndSettle();
    expect(lastMarkdown.trim(), '**Hola**');

    await state.formatHeading(2);
    await tester.pumpAndSettle();
    expect(lastMarkdown.trim(), startsWith('## '));

    await state.formatHeading(3);
    await tester.pumpAndSettle();
    expect(lastMarkdown.trim(), startsWith('### '));

    await state.toggleBulletedList();
    await tester.pumpAndSettle();
    // appflowy's encoder emits '* ' bullets; both are valid GFM list markers.
    expect(lastMarkdown.trim(), matches(RegExp(r'^[*-] ')));
  });

  testWidgets('image insertion inserts an image:// reference', (tester) async {
    await tester.pumpWidget(editor(initial: 'Texto.'));
    await tester.pumpAndSettle();

    final state = tester.state<MarkdownEditorState>(find.byType(MarkdownEditor));
    state.editorState.selection = Selection.collapsed(
      Position(path: [0], offset: 6),
    );
    await state.insertImageReference(_hash, caption: 'Pie');
    // Let the editor's 50ms undo-history debounce timer fire.
    await tester.pump(const Duration(milliseconds: 100));
    expect(lastMarkdown, contains('image://$_hash'));
    // Network images cannot load inside widget tests; drain those errors.
    while (tester.takeException() != null) {}
  });

  testWidgets('table insertion produces a GFM table', (tester) async {
    await tester.pumpWidget(editor(initial: 'Texto.'));
    await tester.pumpAndSettle();

    final state = tester.state<MarkdownEditorState>(find.byType(MarkdownEditor));
    state.editorState.selection = Selection.collapsed(
      Position(path: [0], offset: 6),
    );
    await state.insertTable();
    await tester.pumpAndSettle();
    expect(lastMarkdown, contains('|'));
    // GFM delimiter row: any run of dashes between pipes counts.
    expect(lastMarkdown, matches(RegExp(r'\|[\s:]*-+')));
  });
}
