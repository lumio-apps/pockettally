import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'app_state.dart';
import 'backup.dart';

/// Saves and opens backup files through the system file dialog.
/// No storage permission is needed and nothing is uploaded.
class BackupService {
  /// Asks the user where to save the backup. Returns false if they cancelled.
  static Future<bool> export(AppState state, {required String dialogTitle}) async {
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final bytes =
        Uint8List.fromList(utf8.encode(state.createBackup().toJsonString()));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: 'pockettally-backup-$stamp.json',
      bytes: bytes,
    );
    return path != null;
  }

  /// Lets the user pick a backup file and parses it.
  /// Returns null if they cancelled; throws [FormatException] for a bad file.
  static Future<BackupData?> pick({required String dialogTitle}) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.any,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (result == null) return null;
    if (bytes == null) {
      throw const FormatException('unreadable');
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException('invalid');
    }
    return BackupData.fromJsonString(text);
  }
}
