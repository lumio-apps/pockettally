import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show databaseFactoryFfi, sqfliteFfiInit;

/// True on Windows, Linux and macOS.
bool get isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Folder for the database and bill photos.
///
/// Phones: the app's private documents folder (as in earlier versions).
/// Desktop: the per-user app data folder, e.g.
/// %APPDATA%\Lumio Apps\PocketTally on Windows or
/// ~/.local/share/com.lumio.pockettally on Linux, never the user's
/// Documents folder.
Future<Directory> appDataDirectory() async {
  final dir = isDesktop
      ? await getApplicationSupportDirectory()
      : await getApplicationDocumentsDirectory();
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// sqflite needs its FFI version (bundled SQLite) on desktop.
void initDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    sqflite.databaseFactory = databaseFactoryFfi;
  }
}
