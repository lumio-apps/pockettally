import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The PocketTally logo, light or dark to match the app's theme.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48});

  final double size;

  static const String lightAsset = 'assets/icon/logo_light.png';
  static const String darkAsset = 'assets/icon/logo_dark.png';

  /// Width and height of the image files.
  static const int _fileSize = 512;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Decoded at the size it is shown, not at the file's full size.
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final px = math.min((size * ratio).ceil(), _fileSize);
    return DecoratedBox(
      decoration: BoxDecoration(
        // Same corner as the rounded tile in the image.
        borderRadius: BorderRadius.circular(size * 116 / 512),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.30 : 0.10),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: Image.asset(
        dark ? darkAsset : lightAsset,
        width: size,
        height: size,
        cacheWidth: math.max(px, 1),
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}
