import 'dart:io';

import 'package:flutter/material.dart';

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
        title: const Text('Bill photo', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: Image.file(
            file,
            errorBuilder: (context, error, stack) => const Text(
              'This photo is no longer on the phone.',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
