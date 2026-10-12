import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import 'platform.dart';
import 'utils/lock_guard.dart';

/// Bill photos are copied into the app's own folder, so they stay on the
/// device (on desktop: the per-user app data folder).
/// The profile photo is kept the same way, in its own folder.
class PhotoStore {
  static String? _dirPath;
  static String? _profileDirPath;

  /// Call once at start-up.
  static Future<void> init() async {
    final base = await appDataDirectory();
    final dir = Directory(p.join(base.path, 'receipts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dirPath = dir.path;
    final profile = Directory(p.join(base.path, 'profile'));
    if (!await profile.exists()) await profile.create(recursive: true);
    _profileDirPath = profile.path;
  }

  /// The file for a stored profile photo name, or null if not ready.
  static File? profileFile(String name) => _profileDirPath == null
      ? null
      : File(p.join(_profileDirPath!, name));

  /// Opens the camera or gallery (a file dialog on desktop) for a profile
  /// photo, stores a small copy and returns its file name, or null if the
  /// user cancelled.
  static Future<String?> pickProfile({required bool camera}) async {
    final picked = await LockGuard.around(() => ImagePicker().pickImage(
          source:
              camera && !isDesktop ? ImageSource.camera : ImageSource.gallery,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 512,
          maxHeight: 512,
          imageQuality: 85,
        ));
    if (picked == null) return null;
    return saveProfileBytes(await File(picked.path).readAsBytes(),
        extension: p.extension(picked.path));
  }

  /// Stores profile photo bytes (from the picker or a backup) under a new
  /// name, so a changed photo is never shown from the image cache.
  static Future<String> saveProfileBytes(List<int> bytes,
      {String extension = '.jpg'}) async {
    if (_profileDirPath == null) await init();
    final ext = extension.isEmpty ? '.jpg' : extension.toLowerCase();
    final name = 'profile_${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(p.join(_profileDirPath!, name)).writeAsBytes(bytes, flush: true);
    return name;
  }

  /// Deletes every bill photo and the profile photo (used by "Reset the
  /// app").
  static Future<void> deleteAll() async {
    for (final path in [_dirPath, _profileDirPath]) {
      if (path == null) continue;
      final dir = Directory(path);
      try {
        if (await dir.exists()) await dir.delete(recursive: true);
        await dir.create(recursive: true);
      } catch (_) {}
    }
  }

  /// Deletes a stored profile photo; a missing file is fine.
  static Future<void> deleteProfile(String name) async {
    final f = profileFile(name);
    try {
      if (f != null && await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// The file for a stored photo name, or null if storage is not ready.
  static File? file(String name) =>
      _dirPath == null ? null : File(p.join(_dirPath!, name));

  /// Opens the camera or gallery (a file dialog on desktop) and stores the
  /// chosen photo.
  /// Returns the stored file name, or null if the user cancelled.
  static Future<String?> pick({required bool camera}) async {
    final picked = await LockGuard.around(() => ImagePicker().pickImage(
          source:
              camera && !isDesktop ? ImageSource.camera : ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 80,
        ));
    if (picked == null) return null;
    if (_dirPath == null) await init();
    final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final name = 'bill_${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(picked.path).copy(p.join(_dirPath!, name));
    return name;
  }
}
