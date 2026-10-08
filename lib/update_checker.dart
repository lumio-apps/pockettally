import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Set to false for the F-Droid build (it updates apps by itself):
///   flutter build apk --dart-define=UPDATER=false
const bool kUpdaterEnabled = bool.fromEnvironment('UPDATER', defaultValue: true);

const String kGithubOwner = 'lumio-apps';
const String kGithubRepo = 'pockettally';

class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.notes,
    required this.apkUrl,
  });

  final String version;
  final String notes;
  final String apkUrl;
}

class UpdateChecker {
  /// Returns the newest release if it is newer than the installed app,
  /// or null when the app is up to date.
  static Future<UpdateInfo?> check() async {
    final info = await PackageInfo.fromPlatform();
    final uri = Uri.https(
        'api.github.com', '/repos/$kGithubOwner/$kGithubRepo/releases/latest');
    final res = await http
        .get(uri, headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 15));

    if (res.statusCode == 404) return null; // no release published yet
    if (res.statusCode != 200) {
      throw HttpException('GitHub returned ${res.statusCode}');
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final tag = (json['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (!_isNewer(tag, info.version)) return null;

    final assets = (json['assets'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final apk = assets.firstWhere(
      (a) => (a['name'] as String).toLowerCase().endsWith('.apk'),
      orElse: () => <String, dynamic>{},
    );
    final url = apk['browser_download_url'] as String?;
    if (url == null) return null;

    return UpdateInfo(
      version: tag,
      notes: (json['body'] as String?)?.trim() ?? '',
      apkUrl: url,
    );
  }

  /// Downloads the APK (reporting progress 0..1) and opens the installer.
  static Future<void> downloadAndInstall(
    UpdateInfo update,
    void Function(double progress) onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/pockettally-${update.version}.apk');

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(update.apkUrl));
      final res = await client.send(req);
      if (res.statusCode != 200) {
        throw HttpException('Download failed (${res.statusCode})');
      }
      final total = res.contentLength ?? 0;
      var received = 0;
      final sink = file.openWrite();
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress(received / total);
      }
      await sink.close();
    } finally {
      client.close();
    }

    final result = await OpenFilex.open(
      file.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  static bool _isNewer(String remote, String local) {
    final r = _parts(remote);
    final l = _parts(local);
    for (var i = 0; i < 3; i++) {
      if (r[i] > l[i]) return true;
      if (r[i] < l[i]) return false;
    }
    return false;
  }

  static List<int> _parts(String v) {
    final nums = v
        .split('+')
        .first
        .split('.')
        .map((s) => int.tryParse(s) ?? 0)
        .toList();
    while (nums.length < 3) {
      nums.add(0);
    }
    return nums;
  }
}
