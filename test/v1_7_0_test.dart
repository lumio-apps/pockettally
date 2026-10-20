import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/backup.dart';
import 'package:pockettally/csv_io.dart';
import 'package:pockettally/models.dart';

Entry entry({String? wallet}) => Entry(
      type: EntryType.expense,
      amountMinor: 1250,
      category: 'Food',
      date: DateTime(2026, 10, 3),
      wallet: wallet,
    );

BackupData backup({List<Wallet> wallets = const [], List<Entry>? entries}) =>
    BackupData(
      userName: 'A',
      currencyCode: 'INR',
      weekStartsOnSunday: false,
      monthlyBudgetMinor: 0,
      categories: const [],
      entries: entries ?? [entry(wallet: 'Bank')],
      wallets: wallets,
    );

void main() {
  test('Wallet and entry wallet survive the database map', () {
    final w = Wallet(
        id: 2, name: 'Bank', colorValue: 0xFF64B5F6, openingMinor: 50000);
    final back = Wallet.fromMap(w.toMap());
    expect(back.name, 'Bank');
    expect(back.openingMinor, 50000);
    expect(back.main, isFalse);
    expect(Entry.fromMap({...entry(wallet: 'Bank').toMap(), 'id': 1}).wallet,
        'Bank');
    expect(Entry.fromMap({...entry().toMap(), 'id': 1}).wallet, isNull);
  });

  test('Backup keeps wallets and entry wallets', () {
    final text = backup(wallets: [
      Wallet(name: 'Cash', colorValue: 1, main: true),
      Wallet(name: 'Bank', colorValue: 2, openingMinor: 900),
    ]).toJsonString();
    final b = BackupData.fromJsonString(text);
    expect(b.wallets.map((w) => w.name), ['Cash', 'Bank']);
    expect(b.wallets.first.main, isTrue);
    expect(b.wallets.last.openingMinor, 900);
    expect(b.entries.single.wallet, 'Bank');
  });

  test('An old backup without wallets still reads', () {
    final text = backup(entries: [entry()]).toJsonString();
    expect(text.contains('"wallet"'), isFalse);
    final b = BackupData.fromJsonString(text);
    expect(b.wallets, isEmpty);
    expect(b.entries.single.wallet, isNull);
  });

  test('CSV carries the wallet column only when asked', () {
    final plain = CsvIo.export([entry(wallet: 'Bank')]);
    expect(plain.split('\r\n').first, 'date,type,category,amount,note,tags,period');
    final csv = CsvIo.export([entry(wallet: 'Bank')], walletOf: (e) => e.wallet!);
    expect(csv.split('\r\n').first, endsWith(',wallet'));
    final parsed = CsvIo.parse(csv);
    expect(parsed.entries.single.wallet, 'Bank');
    expect(CsvIo.parse(plain).entries.single.wallet, isNull);
  });

  test('Wallets are wired into the app and all languages', () {
    expect(File('lib/screens/wallets_screen.dart').existsSync(), isTrue);
    expect(File('lib/db.dart').readAsStringSync(), contains('CREATE TABLE IF NOT EXISTS wallets'));
    for (final f in Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.arb'))) {
      final s = f.readAsStringSync();
      for (final k in ['wallets', 'addWallet', 'openingBalance', 'deleteWalletQuestion']) {
        expect(s, contains('"$k"'), reason: f.path);
      }
    }
  });
}
