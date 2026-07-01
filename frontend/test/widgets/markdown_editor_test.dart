import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recetarios/l10n/app_localizations.dart';
import 'package:recetarios/widgets/markdown_editor.dart';
import 'package:recetarios/widgets/markdown_editor_codecs.dart';

import '../helpers/test_database.dart';

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

  Future<Widget> editor({String initial = ''}) async {
    final imageStore = await testImageStore();
    lastMarkdown = initial;
    return _app(MarkdownEditor(
      initialMarkdown: initial,
      imageStore: imageStore,
      onChanged: (value) => lastMarkdown = value,
    ));
  }

  testWidgets('opens in WYSIWYG mode by default with the toolbar', (tester) async {
    await tester.pumpWidget(await editor(initial: 'Hola **mundo**.'));
    await tester.pumpAndSettle();

    expect(find.byType(AppFlowyEditor), findsOneWidget);
    expect(find.byKey(MarkdownEditor.sourceFieldKey), findsNothing);

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
    expect(find.textContaining('**'), findsNothing);
  });

  testWidgets('source toggle reveals raw markdown and syncs edits back',
      (tester) async {
    await tester.pumpWidget(await editor(initial: 'Texto *original* aquí.'));
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

    await tester.tap(find.byTooltip('Fuente'));
    await tester.pumpAndSettle();
    expect(find.byType(AppFlowyEditor), findsOneWidget);
    expect(find.textContaining('Texto nuevo con', findRichText: true), findsOneWidget);
  });

  testWidgets('toolbar formatting produces the expected markdown', (tester) async {
    await tester.pumpWidget(await editor(initial: 'Hola'));
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
    expect(lastMarkdown.trim(), matches(RegExp(r'^[*-] ')));
  });

  testWidgets('image insertion inserts an image:// reference', (tester) async {
    await tester.pumpWidget(await editor(initial: 'Texto.'));
    await tester.pumpAndSettle();

    final state = tester.state<MarkdownEditorState>(find.byType(MarkdownEditor));
    state.editorState.selection = Selection.collapsed(
      Position(path: [0], offset: 6),
    );
    await state.insertImageReference(_hash, caption: 'Pie');
    await tester.pump(const Duration(milliseconds: 100));
    expect(lastMarkdown, contains('image://$_hash'));
    while (tester.takeException() != null) {}
  });

  testWidgets('real-world content opens in WYSIWYG mode (round-trip safe)',
      (tester) async {
    const initial = '## Las setas\n\n'
        'Primer párrafo con **negrita**.\n\n'
        'Segundo párrafo, separado.\n\n'
        '![Pie de foto](image://$_hash)\n\n'
        '![Una](image://$_hash)\n![Dos](image://$_hash)\n\n'
        '### Subsección\n\n'
        '- uno\n- dos\n';
    await tester.pumpWidget(await editor(initial: initial));
    await tester.pump();

    expect(find.byType(AppFlowyEditor), findsOneWidget);
    expect(find.byKey(MarkdownEditor.sourceFieldKey), findsNothing);
    while (tester.takeException() != null) {}
  });

  testWidgets('captions and galleries survive the WYSIWYG round trip',
      (tester) async {
    const initial = 'Texto.\n\n'
        '![Pie de foto](image://$_hash)\n\n'
        '![Una](image://$_hash)\n![Dos](image://$_hash)';
    await tester.pumpWidget(await editor(initial: initial));
    await tester.pump();

    final state = tester.state<MarkdownEditorState>(find.byType(MarkdownEditor));
    final encoded = encodeDocumentToMarkdown(state.editorState.document);
    expect(encoded, initial);
    while (tester.takeException() != null) {}
  });

  testWidgets('table insertion produces a GFM table', (tester) async {
    await tester.pumpWidget(await editor(initial: 'Texto.'));
    await tester.pumpAndSettle();

    final state = tester.state<MarkdownEditorState>(find.byType(MarkdownEditor));
    state.editorState.selection = Selection.collapsed(
      Position(path: [0], offset: 6),
    );
    await state.insertTable();
    await tester.pumpAndSettle();
    expect(lastMarkdown, contains('|'));
    expect(lastMarkdown, matches(RegExp(r'\|[\s:]*-+')));
  });
}
