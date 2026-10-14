import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_state.dart';
import 'backup.dart';
import 'photo_store.dart';

/// Writes a backup file by itself, every day or every week, when the app
/// is opened. Only the newest [keep] automatic backups are kept.
///
/// Android: Documents/PocketTally, which stays when the app is removed.
/// Where that folder cannot be written (Android 9 and older), the app's own
/// folder on the phone storage (Android/data/…) is used instead.
/// Computers: Documents/PocketTally.
class AutoBackup {
  static const int keep = 5;
  static const String prefix = 'pockettally-auto-';
  static bool _running = false;

  /// Makes a backup when one is due (or always with [force]).
  /// Returns true when a file was written.
  static Future<bool> runIfDue(AppState state, {bool force = false}) async {
    if (_running || !state.onboarded) return false;
    if (!force) {
      if (!state.autoBackupOn) return false;
      final last = state.lastAutoBackup;
      if (last != null &&
          DateTime.now().difference(last) <
              Duration(days: state.autoBackupDays) - const Duration(hours: 1)) {
        return false;
      }
    }
    _running = true;
    try {
      // Photos are not loaded here: they are read one by one while writing.
      final names =
          state.backupWithPhotos ? state.billPhotoNames() : <String>{};
      final dir = await _write(state.createBackup(), names);
      await state.markAutoBackup(ok: dir != null, folder: dir?.path);
      if (dir != null) await _prune(dir);
      return dir != null;
    } catch (_) {
      await state.markAutoBackup(ok: false);
      return false;
    } finally {
      _running = false;
    }
  }

  static String _fileName() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '$prefix${n.year}-${two(n.month)}-${two(n.day)}_'
        '${two(n.hour)}${two(n.minute)}.json';
  }

  /// Tries the folders in order; returns the one that worked.
  static Future<Directory?> _write(BackupData data, Set<String> photos) async {
    for (final dir in await _candidates()) {
      try {
        if (!await dir.exists()) await dir.create(recursive: true);
        await data.writeToFile(
          File(p.join(dir.path, _fileName())),
          photoNames: photos,
          readPhoto: PhotoStore.readBill,
        );
        return dir;
      } catch (_) {
        // Not allowed here; try the next folder.
      }
    }
    return null;
  }

  static Future<List<Directory>> _candidates() async {
    final list = <Directory>[];
    if (Platform.isAndroid) {
      list.add(Directory('/storage/emulated/0/Documents/PocketTally'));
      final ext = await getExternalStorageDirectory();
      if (ext != null) list.add(Directory(p.join(ext.path, 'Backups')));
      list.add(Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'Backups')));
    } else {
      list.add(Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'PocketTally')));
    }
    return list;
  }

  /// Removes the oldest automatic backups, keeping [keep].
  static Future<void> _prune(Directory dir) async {
    try {
      final files = <File>[];
      await for (final f in dir.list()) {
        final name = p.basename(f.path);
        if (f is File && name.startsWith(prefix) && name.endsWith('.json')) {
          files.add(f);
        }
      }
      // Names hold the date and time, so sorting by name sorts by age.
      files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
      for (final f in files.skip(keep)) {
        await f.delete();
      }
    } catch (_) {}
  }
}
