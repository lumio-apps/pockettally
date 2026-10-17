import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/theme.dart';
import 'package:pockettally/widgets/glass.dart';

void main() {
  test('Pages are transparent so the glass background shows', () {
    for (final b in [Brightness.light, Brightness.dark]) {
      final theme = buildTheme(b);
      expect(theme.scaffoldBackgroundColor, Colors.transparent);
      expect(theme.appBarTheme.backgroundColor, Colors.transparent);
      // Glass cards are translucent.
      expect(theme.cardTheme.color!.a, lessThan(1));
    }
  });

  test('Every platform uses the glass page transition', () {
    final builders = buildTheme(Brightness.dark).pageTransitionsTheme.builders;
    for (final p in [
      TargetPlatform.android,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ]) {
      expect(builders[p], isA<GlassPageTransitionsBuilder>());
    }
  });

  testWidgets('GlassBackground and GlassCard draw in both modes',
      (tester) async {
    for (final b in [Brightness.light, Brightness.dark]) {
      for (final palette in kPalettes) {
        await tester.pumpWidget(MaterialApp(
          theme: buildTheme(b, palette),
          home: const GlassBackground(
            child: Center(
              child: GlassCard(
                padding: EdgeInsets.all(16),
                child: Text('Balance'),
              ),
            ),
          ),
        ));
        expect(find.text('Balance'), findsOneWidget);
      }
    }
  });

}
