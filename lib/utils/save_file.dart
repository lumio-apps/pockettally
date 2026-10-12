import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../platform.dart';
import 'lock_guard.dart';

/// Asks where to save [bytes] and writes them there.
/// Returns false if the user cancelled.
Future<bool> saveBytesAs({
  required String dialogTitle,
  required String fileName,
  required Uint8List bytes,
}) async {
  final path = await LockGuard.around(() => FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        bytes: bytes,
      ));
  if (path == null) return false;
  // On desktop the dialog only returns the chosen path; write the file.
  if (isDesktop) await File(path).writeAsBytes(bytes, flush: true);
  return true;
}
