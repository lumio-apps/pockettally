import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'utils/lock_guard.dart';

const String kGithubOwner = 'lumio-apps';
const String kGithubRepo = 'pockettally';

class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.notes,
    required this.downloadUrl,
    required this.pageUrl,
  });

  final String version;
  final String notes;

  /// The APK of the release.
  final String downloadUrl;

  /// The release page on GitHub.
  final String pageUrl;
}

/// Looks for a newer release on GitHub, only when the user taps
/// "Check for updates" in Settings. Nothing is checked in the background and
/// nothing about the user or the phone is sent.
class UpdateChecker {
  /// Returns the newest release if it is newer than the installed app and
  /// has an APK, or null when the app is up to date.
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
    if (!isNewer(tag, info.version)) return null;

    final assets = {
      for (final a in (json['assets'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>())
        (a['name'] as String): (a['browser_download_url'] as String),
    };
    final url = pickApkUrl(assets);
    if (url == null) return null;

    return UpdateInfo(
      version: tag,
      notes: (json['body'] as String?)?.trim() ?? '',
      downloadUrl: url,
      pageUrl: json['html_url'] as String? ??
          'https://github.com/$kGithubOwner/$kGithubRepo/releases/latest',
    );
  }

  /// Downloads the APK (reporting progress 0..1) and opens the installer.
  static Future<void> downloadAndInstall(
    UpdateInfo update,
    void Function(double progress) onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}${Platform.pathSeparator}pockettally-${update.version}.apk');
    await _download(update.downloadUrl, file, onProgress);

    final result = await LockGuard.around(() => OpenFilex.open(
          file.path,
          type: 'application/vnd.android.package-archive',
        ));
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }

  static Future<void> _download(
    String url,
    File file,
    void Function(double progress) onProgress,
  ) async {
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', Uri.parse(url)));
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
  }

  /// The APK from the release assets (file name -> download URL): the one
  /// ending in "-android.apk", else any other APK. Null when there is none.
  static String? pickApkUrl(Map<String, String> assets) {
    final apks = {
      for (final e in assets.entries)
        if (e.key.toLowerCase().endsWith('.apk')) e.key.toLowerCase(): e.value,
    };
    if (apks.isEmpty) return null;
    for (final e in apks.entries) {
      if (e.key.endsWith('-android.apk')) return e.value;
    }
    return apks.values.first;
  }

  /// True when version [remote] (e.g. "1.4.0") is newer than [local].
  static bool isNewer(String remote, String local) {
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
