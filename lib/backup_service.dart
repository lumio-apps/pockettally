import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'app_state.dart';
import 'backup.dart';
import 'csv_io.dart';
import 'utils/save_file.dart';

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
    return saveBytesAs(
      dialogTitle: dialogTitle,
      fileName: 'pockettally-backup-$stamp.json',
      bytes: bytes,
    );
  }

  /// Saves all entries as a CSV file. Returns false if cancelled.
  static Future<bool> exportCsv(AppState state,
      {required String dialogTitle}) async {
    final now = DateTime.now();
    final stamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    // The BOM makes Excel open the file as UTF-8 (names in any script).
    final bytes = Uint8List.fromList(
        utf8.encode('\uFEFF${CsvIo.export(state.entries)}'));
    return saveBytesAs(
      dialogTitle: dialogTitle,
      fileName: 'pockettally-entries-$stamp.csv',
      bytes: bytes,
    );
  }

  /// Lets the user pick a CSV file and reads its entries. Returns null if
  /// cancelled; throws [FormatException] when it is not a usable CSV.
  static Future<CsvResult?> pickCsv({required String dialogTitle}) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.any,
      withData: true,
    );
    if (result == null) return null;
    final bytes = result.files.single.bytes;
    if (bytes == null) throw const FormatException('unreadable');
    return CsvIo.parse(utf8.decode(bytes, allowMalformed: true));
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
