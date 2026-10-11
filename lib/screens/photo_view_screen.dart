import 'dart:io';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// Full-screen bill photo with pinch to zoom.
class PhotoViewScreen extends StatelessWidget {
  const PhotoViewScreen({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(context.l10n.billPhoto,
            style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(
            file,
            errorBuilder: (context, error, stack) => Text(
              context.l10n.photoGone,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
