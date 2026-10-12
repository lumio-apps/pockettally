import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'utils/lock_guard.dart';

/// Set to false for the F-Droid build (it updates apps by itself):
///   flutter build apk --dart-define=UPDATER=false
const bool kUpdaterEnabled = bool.fromEnvironment('UPDATER', defaultValue: true);

const String kGithubOwner = 'lumio-apps';
const String kGithubRepo = 'pockettally';

/// File name endings of the release files, per platform (lower case).
const String kWindowsSetupSuffix = '-windows-setup.exe';
const String kLinuxAppImageSuffix = '-linux-x86_64.appimage';

class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.notes,
    required this.downloadUrl,
    required this.pageUrl,
  });

  final String version;
  final String notes;

  /// The file for this device: APK, Windows installer or Linux AppImage.
  final String downloadUrl;

  /// The release page on GitHub.
  final String pageUrl;
}

class UpdateChecker {
  /// Returns the newest release if it is newer than the installed app and
  /// has a file for this device, or null when the app is up to date.
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
    final String? url;
    if (Platform.isWindows) {
      url = pickDesktopUrl(assets, kWindowsSetupSuffix);
    } else if (Platform.isLinux) {
      url = pickDesktopUrl(assets, kLinuxAppImageSuffix);
    } else {
      url = pickApkUrl(assets, deviceAbi());
    }
    if (url == null) return null;

    return UpdateInfo(
      version: tag,
      notes: (json['body'] as String?)?.trim() ?? '',
      downloadUrl: url,
      pageUrl: json['html_url'] as String? ??
          'https://github.com/$kGithubOwner/$kGithubRepo/releases/latest',
    );
  }

  /// Downloads the update (reporting progress 0..1) and installs it:
  /// - Android: opens the APK installer.
  /// - Windows: starts the setup and closes the app; the setup replaces
  ///   the app and opens it again.
  /// - Linux AppImage: replaces the AppImage file and restarts it. Other
  ///   Linux installs (tar.gz) open the release page instead.
  static Future<void> downloadAndInstall(
    UpdateInfo update,
    void Function(double progress) onProgress,
  ) async {
    if (Platform.isLinux && Platform.environment['APPIMAGE'] == null) {
      await Process.start('xdg-open', [update.pageUrl],
          mode: ProcessStartMode.detached);
      return;
    }

    final dir = await getTemporaryDirectory();
    final name = Platform.isWindows
        ? 'pockettally-${update.version}-setup.exe'
        : Platform.isLinux
            ? 'pockettally-${update.version}.AppImage'
            : 'pockettally-${update.version}.apk';
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await _download(update.downloadUrl, file, onProgress);

    if (Platform.isWindows) {
      await Process.start(
        file.path,
        ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART'],
        mode: ProcessStartMode.detached,
      );
      exit(0);
    }

    if (Platform.isLinux) {
      final current = Platform.environment['APPIMAGE']!;
      // Copy next to the running AppImage first, then swap in one step.
      final next = '$current.new';
      await file.copy(next);
      await Process.run('chmod', ['+x', next]);
      await File(next).rename(current);
      await Process.start(current, [], mode: ProcessStartMode.detached);
      exit(0);
    }

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

  /// The Android ABI this app runs as, matching the split APK names:
  /// "arm64-v8a", "armeabi-v7a" or "x86_64". Null when unknown.
  static String? deviceAbi() {
    final abi = Abi.current();
    if (abi == Abi.androidArm64) return 'arm64-v8a';
    if (abi == Abi.androidArm) return 'armeabi-v7a';
    if (abi == Abi.androidX64) return 'x86_64';
    return null;
  }

  /// The release file whose name ends with [suffix] (any letter case),
  /// e.g. "pockettally-v0.7.0-windows-setup.exe".
  static String? pickDesktopUrl(Map<String, String> assets, String suffix) {
    for (final e in assets.entries) {
      if (e.key.toLowerCase().endsWith(suffix)) return e.value;
    }
    return null;
  }

  /// Picks the smallest APK that fits this phone from release assets
  /// (file name -> download URL):
  ///   1. the split APK for [abi], e.g. pockettally-v0.6.0-arm64-v8a.apk
  ///   2. the universal APK (works everywhere, bigger download)
  ///   3. any APK (releases before 0.6.0 had only one)
  static String? pickApkUrl(Map<String, String> assets, String? abi) {
    final apks = {
      for (final e in assets.entries)
        if (e.key.toLowerCase().endsWith('.apk')) e.key.toLowerCase(): e.value,
    };
    if (apks.isEmpty) return null;
    if (abi != null) {
      for (final e in apks.entries) {
        if (e.key.endsWith('-$abi.apk')) return e.value;
      }
    }
    for (final e in apks.entries) {
      if (e.key.endsWith('-universal.apk')) return e.value;
    }
    const splits = ['-arm64-v8a.apk', '-armeabi-v7a.apk', '-x86_64.apk'];
    for (final e in apks.entries) {
      if (!splits.any(e.key.endsWith)) return e.value;
    }
    return null;
  }

  /// True when version [remote] (e.g. "0.7.0") is newer than [local].
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
