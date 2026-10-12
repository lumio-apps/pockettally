import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/widgets/app_logo.dart';

void main() {
  Future<String> shownAsset(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(MaterialApp(
      // A new key for each theme builds the app fresh. With the same app,
      // the theme would fade from light to dark over a few frames and the
      // first frame would still be light.
      key: ValueKey(brightness),
      theme: ThemeData(brightness: brightness),
      home: const Scaffold(body: Center(child: AppLogo(size: 48))),
    ));
    final provider = tester.widget<Image>(find.byType(Image)).image;
    final asset = (provider is ResizeImage ? provider.imageProvider : provider)
        as AssetImage;
    return asset.assetName;
  }

  testWidgets('the logo follows the light or dark theme', (tester) async {
    expect(await shownAsset(tester, Brightness.light), AppLogo.lightAsset);
    expect(await shownAsset(tester, Brightness.dark), AppLogo.darkAsset);
  });

  test('all icon and splash pictures are there', () {
    for (final path in [
      AppLogo.lightAsset,
      AppLogo.darkAsset,
      'assets/icon/icon.png',
      'assets/icon/icon_background.png',
      'assets/icon/icon_foreground.png',
      'assets/icon/icon_monochrome.png',
      'assets/icon/logo.png',
      'assets/splash/splash.png',
      'assets/splash/splash_android12.png',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}