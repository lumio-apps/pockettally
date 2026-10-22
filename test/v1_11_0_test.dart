import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/theme.dart';
import 'package:pockettally/widgets/neo.dart';

void main() {
  test('Light palette: white cards on a tinted page', () {
    final p = kPalettes.first;
    final n = NeoPalette.from(p, Brightness.light);
    expect(n.base, Colors.white);
    expect(n.page, p.pageLight);
    expect(n.page, isNot(n.base));
  });

  test('Dark palette uses the dark card and page colors', () {
    final p = kPalettes.first;
    final n = NeoPalette.from(p, Brightness.dark);
    expect(n.base, p.surfaceDark);
    expect(n.page, p.pageDark);
  });

  test('The theme paints the page with the tinted color', () {
    final p = kPalettes.first;
    expect(buildTheme(Brightness.light, p).scaffoldBackgroundColor,
        p.pageLight);
  });

  test('Every platform uses the fade page transition', () {
    final builders = buildTheme(Brightness.light).pageTransitionsTheme.builders;
    expect(builders[TargetPlatform.android], isA<NeoPageTransitionsBuilder>());
  });
}
