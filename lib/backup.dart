import 'dart:convert';
import 'dart:io';

import 'models.dart';

/// Everything needed to move PocketTally to another phone.
///
/// The backup is a plain JSON file that the user saves wherever they choose.
/// The app never uploads it anywhere.
class BackupData {
  BackupData({
    required this.userName,
    required this.currencyCode,
    required this.weekStartsOnSunday,
    required this.monthlyBudgetMinor,
    required this.categories,
    required this.entries,
    this.debts = const [],
    this.goals = const [],
    this.recurring = const [],
    this.favorites = const [],
    this.wallets = const [],
    this.transfers = const [],
    this.subscriptions = const [],
    this.numberStyle,
    this.decimals,
    this.palette,
    this.profilePhoto,
    this.photos = const {},
    DateTime? exportedAt,
  }) : exportedAt = exportedAt ?? DateTime.now();

  static const String appId = 'PocketTally';

  /// 1 = app 0.3.0, 2 = app 0.5.0 (adds debts and goals).
  /// App 0.6.0 only adds optional keys (number format, category order),
  /// so it stays 2 and older versions can still read its backups.
  static const int formatVersion = 2;

  final String userName;
  final String currencyCode;
  final bool weekStartsOnSunday;
  final int monthlyBudgetMinor;
  final List<EntryCategory> categories;
  final List<Entry> entries;
  final List<Debt> debts;
  final List<SavingsGoal> goals;
  final List<RecurringRule> recurring;
  final List<Favorite> favorites;

  /// Wallets (empty in backups made before app 1.7.0).
  final List<Wallet> wallets;

  /// Money moved between wallets (empty before app 1.8.0).
  final List<Transfer> transfers;

  /// Bills you pay again and again (empty before app 1.9.0).
  final List<Subscription> subscriptions;

  /// Optional settings (null when the backup is older than 0.6.0).
  final String? numberStyle;
  final int? decimals;
  final String? palette;

  /// Profile photo (JPEG/PNG bytes), stored as base64; null if none.
  final List<int>? profilePhoto;

  /// Bill photos by file name (only in backups made "with bill photos").
  /// Entries keep their photo name only when the photo is included.
  final Map<String, List<int>> photos;
  final DateTime exportedAt;

  static const JsonEncoder _encoder = JsonEncoder.withIndent(' ');

  /// The whole backup as one text, with the bill photos inside it.
  /// For a big photo collection use [writeToFile], which needs far less memory.
  String toJsonString() =>
      _encoder.convert(_toMap(photos.keys.toSet(), inlinePhotos: true));

  /// Writes the backup to [file] without holding all bill photos in memory:
  /// the text is written first, then the photos named in [photoNames] one by
  /// one (read with [readPhoto]). The file is written under a temporary name
  /// and renamed at the end, so a stopped phone never leaves a half backup.
  /// The result is the same format as [toJsonString].
  Future<void> writeToFile(
    File file, {
    required Iterable<String> photoNames,
    required List<int>? Function(String name) readPhoto,
  }) async {
    final names = photoNames.toSet();
    final text = _encoder.convert(_toMap(names, inlinePhotos: false));
    final end = text.lastIndexOf('}');
    final tmp = File('${file.path}.tmp');
    final sink = tmp.openWrite();
    try {
      sink.write(text.substring(0, end).trimRight());
      if (names.isNotEmpty) {
        sink.write(',\n "photos": {');
        var first = true;
        for (final name in names) {
          final bytes = readPhoto(name);
          if (bytes == null) continue;
          sink.write('${first ? '' : ','}\n  ${jsonEncode(name)}: '
              '"${base64Encode(bytes)}"');
          first = false;
          // Hands the written part to the system, so it can be freed.
          await sink.flush();
        }
        sink.write('\n }');
      }
      sink.write('\n}\n');
      await sink.flush();
      await sink.close();
      await tmp.rename(file.path);
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      try {
        if (tmp.existsSync()) tmp.deleteSync();
      } catch (_) {}
      rethrow;
    }
  }

  Map<String, dynamic> _toMap(Set<String> photoNames,
          {required bool inlinePhotos}) =>
      {
        'app': appId,
        'format': formatVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'settings': {
          'userName': userName,
          'currency': currencyCode,
          'weekStart': weekStartsOnSunday ? 'sunday' : 'monday',
          'monthlyBudget': monthlyBudgetMinor,
          if (numberStyle != null) 'numberStyle': numberStyle,
          if (decimals != null) 'decimals': decimals,
          if (palette != null) 'palette': palette,
          if (profilePhoto != null && profilePhoto!.isNotEmpty)
            'profilePhoto': base64Encode(profilePhoto!),
        },
        'categories': [
          for (final c in categories)
            {
              'name': c.name,
              'type': c.type.name,
              'color': c.colorValue,
              'budget': c.budgetMinor,
              'position': c.position,
              'hidden': c.hidden,
              if (c.icon != null) 'icon': c.icon,
            },
        ],
        'wallets': [
          for (final w in wallets)
            {
              'name': w.name,
              'color': w.colorValue,
              'opening': w.openingMinor,
              if (w.main) 'main': true,
            },
        ],
        if (subscriptions.isNotEmpty)
          'subscriptions': [
            for (final s in subscriptions)
              {
                'name': s.name,
                'amountMinor': s.amountMinor,
                'every': s.every.name,
                'nextDate': _dateString(s.nextDate),
                'anchorDay': s.anchorDay,
                'category': s.category,
                if (s.wallet != null) 'wallet': s.wallet,
                'remindDays': s.remindDays,
                'paused': s.paused,
              },
          ],
        if (transfers.isNotEmpty)
          'transfers': [
            for (final t in transfers)
              {
                'from': t.from,
                'to': t.to,
                'amountMinor': t.amountMinor,
                'date': _dateString(t.date),
                'note': t.note,
              },
          ],
        'entries': [
          for (final e in entries)
            {
              'type': e.type.name,
              'amountMinor': e.amountMinor,
              'category': e.category,
              'date': _dateString(e.date),
              'note': e.note,
              'period': e.period?.name,
              if (e.tags.isNotEmpty) 'tags': e.tags,
              if (e.minutes != null) 'time': e.minutes,
              if (e.wallet != null) 'wallet': e.wallet,
              if (e.photo != null && photoNames.contains(e.photo))
                'photo': e.photo,
            },
        ],
        'recurring': [
          for (final r in recurring)
            {
              'type': r.type.name,
              'amountMinor': r.amountMinor,
              'category': r.category,
              'note': r.note,
              'period': r.period?.name,
              'tags': r.tags,
              'every': r.every.name,
              'anchorDay': r.anchorDay,
              'nextDate': _dateString(r.nextDate),
              'paused': r.paused,
            },
        ],
        'favorites': [
          for (final f in favorites)
            {
              'type': f.type.name,
              'amountMinor': f.amountMinor,
              'category': f.category,
              'note': f.note,
              'period': f.period?.name,
            },
        ],
        'debts': [
          for (final d in debts)
            {
              'person': d.person,
              'type': d.type.name,
              'amountMinor': d.amountMinor,
              'paidMinor': d.paidMinor,
              'date': _dateString(d.date),
              'note': d.note,
              // Local date and time, e.g. "2026-10-15T10:00:00.000".
              if (d.remindAt != null) 'remindAt': d.remindAt!.toIso8601String(),
            },
        ],
        if (inlinePhotos && photos.isNotEmpty)
          'photos': {
            for (final p in photos.entries) p.key: base64Encode(p.value),
          },
        'goals': [
          for (final g in goals)
            {
              'name': g.name,
              'targetMinor': g.targetMinor,
              'savedMinor': g.savedMinor,
              'color': g.colorValue,
            },
        ],
      };

  /// Parses a backup file. Throws [FormatException] whose message is an
  /// error code (see backupErrorMessage in l10n/l10n.dart)
  /// when the file is not a PocketTally backup.
  static BackupData fromJsonString(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw const FormatException('invalid');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != appId) {
      throw const FormatException('not_ours');
    }
    final format = decoded['format'];
    if (format is! int || format > formatVersion) {
      throw const FormatException('too_new');
    }

    try {
      final settings = (decoded['settings'] as Map<String, dynamic>?) ?? {};
      final categories = [
        for (final c in (decoded['categories'] as List<dynamic>? ?? []))
          EntryCategory(
            name: (c as Map<String, dynamic>)['name'] as String,
            type: EntryType.values.byName(c['type'] as String),
            colorValue: c['color'] as int,
            budgetMinor: c['budget'] as int?,
            position: (c['position'] as int?) ?? 0,
            hidden: c['hidden'] == true,
            icon: c['icon'] as String?,
          ),
      ];
      final entries = [
        for (final e in (decoded['entries'] as List<dynamic>? ?? []))
          Entry(
            type: EntryType.values.byName((e as Map<String, dynamic>)['type'] as String),
            amountMinor: e['amountMinor'] as int,
            category: e['category'] as String,
            date: DateTime.parse(e['date'] as String),
            note: (e['note'] as String?) ?? '',
            period: e['period'] == null
                ? null
                : IncomePeriod.values.byName(e['period'] as String),
            tags: [
              for (final t in (e['tags'] as List<dynamic>? ?? [])) t as String,
            ],
            photo: e['photo'] as String?,
            minutes: e['time'] as int?,
            wallet: e['wallet'] as String?,
          ),
      ];
      final wallets = [
        for (final w in (decoded['wallets'] as List<dynamic>? ?? []))
          Wallet(
            name: (w as Map<String, dynamic>)['name'] as String,
            colorValue: w['color'] as int,
            openingMinor: (w['opening'] as int?) ?? 0,
            main: w['main'] == true,
          ),
      ];
      final subscriptions = [
        for (final s in (decoded['subscriptions'] as List<dynamic>? ?? []))
          Subscription(
            name: (s as Map<String, dynamic>)['name'] as String,
            amountMinor: s['amountMinor'] as int,
            every: RepeatEvery.values.byName(s['every'] as String),
            nextDate: DateTime.parse(s['nextDate'] as String),
            anchorDay: (s['anchorDay'] as int?) ?? 1,
            category: (s['category'] as String?) ?? kOtherCategory,
            wallet: s['wallet'] as String?,
            remindDays: (s['remindDays'] as int?) ?? 1,
            paused: s['paused'] == true,
          ),
      ];
      final transfers = [
        for (final t in (decoded['transfers'] as List<dynamic>? ?? []))
          Transfer(
            from: (t as Map<String, dynamic>)['from'] as String,
            to: t['to'] as String,
            amountMinor: t['amountMinor'] as int,
            date: DateTime.parse(t['date'] as String),
            note: (t['note'] as String?) ?? '',
          ),
      ];
      final photos = <String, List<int>>{};
      final rawPhotos = decoded['photos'];
      if (rawPhotos is Map<String, dynamic>) {
        for (final p in rawPhotos.entries) {
          final bytes = _photo(p.value);
          // Only plain file names, never a path.
          if (bytes != null && _safeName(p.key)) photos[p.key] = bytes;
        }
      }
      IncomePeriod? period(Object? v) =>
          v == null ? null : IncomePeriod.values.byName(v as String);
      final recurring = [
        for (final r in (decoded['recurring'] as List<dynamic>? ?? []))
          RecurringRule(
            type: EntryType.values.byName((r as Map<String, dynamic>)['type'] as String),
            amountMinor: r['amountMinor'] as int,
            category: r['category'] as String,
            note: (r['note'] as String?) ?? '',
            period: period(r['period']),
            tags: [for (final t in (r['tags'] as List<dynamic>? ?? [])) t as String],
            every: RepeatEvery.values.byName(r['every'] as String),
            anchorDay: r['anchorDay'] as int,
            nextDate: DateTime.parse(r['nextDate'] as String),
            paused: r['paused'] == true,
          ),
      ];
      final favorites = [
        for (final f in (decoded['favorites'] as List<dynamic>? ?? []))
          Favorite(
            type: EntryType.values.byName((f as Map<String, dynamic>)['type'] as String),
            amountMinor: f['amountMinor'] as int,
            category: f['category'] as String,
            note: (f['note'] as String?) ?? '',
            period: period(f['period']),
          ),
      ];
      final debts = [
        for (final d in (decoded['debts'] as List<dynamic>? ?? []))
          Debt(
            person: (d as Map<String, dynamic>)['person'] as String,
            type: DebtType.values.byName(d['type'] as String),
            amountMinor: d['amountMinor'] as int,
            paidMinor: (d['paidMinor'] as int?) ?? 0,
            date: DateTime.parse(d['date'] as String),
            note: (d['note'] as String?) ?? '',
            remindAt: d['remindAt'] is String
                ? DateTime.tryParse(d['remindAt'] as String)
                : null,
          ),
      ];
      final goals = [
        for (final g in (decoded['goals'] as List<dynamic>? ?? []))
          SavingsGoal(
            name: (g as Map<String, dynamic>)['name'] as String,
            targetMinor: g['targetMinor'] as int,
            savedMinor: (g['savedMinor'] as int?) ?? 0,
            colorValue: g['color'] as int,
          ),
      ];
      return BackupData(
        recurring: recurring,
        favorites: favorites,
        wallets: wallets,
        transfers: transfers,
        subscriptions: subscriptions,
        debts: debts,
        goals: goals,
        userName: (settings['userName'] as String?) ?? '',
        currencyCode: (settings['currency'] as String?) ?? 'INR',
        weekStartsOnSunday: settings['weekStart'] == 'sunday',
        monthlyBudgetMinor: (settings['monthlyBudget'] as int?) ?? 0,
        numberStyle: settings['numberStyle'] as String?,
        decimals: settings['decimals'] as int?,
        palette: settings['palette'] as String?,
        profilePhoto: _photo(settings['profilePhoto']),
        photos: photos,
        categories: categories,
        entries: entries,
        exportedAt: DateTime.tryParse(decoded['exportedAt'] as String? ?? ''),
      );
    } catch (_) {
      throw const FormatException('damaged');
    }
  }

  static bool _safeName(String name) =>
      RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(name) && !name.startsWith('.');

  /// A damaged photo never stops a restore: it is just left out.
  static List<int>? _photo(Object? v) {
    if (v is! String || v.isEmpty) return null;
    try {
      return base64Decode(v);
    } on FormatException {
      return null;
    }
  }

  static String _dateString(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
