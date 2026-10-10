import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bill photos are copied into the app's private folder, so they stay on
/// the phone and disappear when the app is uninstalled.
class PhotoStore {
  static String? _dirPath;

  /// Call once at start-up.
  static Future<void> init() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'receipts'));
    if (!await dir.exists()) await dir.create(recursive: true);
    _dirPath = dir.path;
  }

  /// The file for a stored photo name, or null if storage is not ready.
  static File? file(String name) =>
      _dirPath == null ? null : File(p.join(_dirPath!, name));

  /// Opens the camera or gallery and stores the chosen photo.
  /// Returns the stored file name, or null if the user cancelled.
  static Future<String?> pick({required bool camera}) async {
    final picked = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return null;
    if (_dirPath == null) await init();
    final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final name = 'bill_${DateTime.now().millisecondsSinceEpoch}$ext';
    await File(picked.path).copy(p.join(_dirPath!, name));
    return name;
  }
}
