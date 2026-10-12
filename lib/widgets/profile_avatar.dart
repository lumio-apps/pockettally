import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme.dart';

/// The user's profile photo, or the first letter of their name when no
/// photo is set.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.state, this.radius = 22});

  final AppState state;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final file = state.profilePhotoFile;
    final brand = BrandColors.of(context).brand;
    if (file != null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: brand,
        backgroundImage: FileImage(file),
        // A broken image file falls back to the plain circle.
        onBackgroundImageError: (_, __) {},
      );
    }
    final name = state.userName;
    return CircleAvatar(
      radius: radius,
      backgroundColor: brand,
      child: Text(
        name.isEmpty ? '?' : name.characters.first.toUpperCase(),
        style: TextStyle(
          color: kAccent,
          fontWeight: FontWeight.w800,
          fontSize: radius * 0.82,
        ),
      ),
    );
  }
}
