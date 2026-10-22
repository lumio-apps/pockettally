import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/theme.dart';
import 'package:pockettally/widgets/neo.dart';

void main() {
  test('Pages use the tinted page color and cards the card color', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      for (final palette in kPalettes) {
        final theme = buildTheme(b, palette);
        final neo = NeoPalette.from(palette, b);
        expect(theme.scaffoldBackgroundColor, neo.page);
        expect(theme.cardTheme.color, neo.base);
        expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      }
    }
  });

  test('The card border is visible against the card and the page', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      for (final palette in kPalettes) {
        final n = NeoPalette.from(palette, b);
        expect(n.lo, isNot(n.base));
        expect(n.well, isNot(n.base));
      }
    }
  });

  test('Every platform uses the neo page transition', () {
    final builders = buildTheme(Brightness.dark).pageTransitionsTheme.builders;
    for (final p in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(builders[p], isA<NeoPageTransitionsBuilder>());
    }
  });

  testWidgets('NeoCard and NeoInset draw in both modes', (tester) async {
    for (final b in [Brightness.light, Brightness.dark]) {
      for (final palette in kPalettes) {
        await tester.pumpWidget(MaterialApp(
          theme: buildTheme(b, palette),
          home: const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeoCard(
                    padding: EdgeInsets.all(16),
                    child: Text('Balance'),
                  ),
                  NeoInset(
                    padding: EdgeInsets.all(16),
                    child: Text('Income'),
                  ),
                ],
              ),
            ),
          ),
        ));
        expect(find.text('Balance'), findsOneWidget);
        expect(find.text('Income'), findsOneWidget);
      }
    }
  });

  testWidgets('A tapped NeoCard calls onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Scaffold(
        body: Center(
          child: NeoCard(
            onTap: () => taps++,
            padding: const EdgeInsets.all(24),
            child: const Text('Tap me'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Tap me'));
    await tester.pumpAndSettle();
    expect(taps, 1);
  });

  testWidgets('Cards are flat: a border and no shadow', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: const Scaffold(
        body: Center(
          child: NeoCard(padding: EdgeInsets.all(16), child: Text('Flat')),
        ),
      ),
    ));
    final decos = tester
        .widgetList<DecoratedBox>(find.descendant(
            of: find.byType(NeoCard), matching: find.byType(DecoratedBox)))
        .map((b) => b.decoration)
        .whereType<BoxDecoration>();
    expect(decos.any((d) => d.border != null), isTrue);
    expect(decos.expand((d) => d.boxShadow ?? const <BoxShadow>[]), isEmpty);
  });
}
