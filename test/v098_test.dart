import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pockettally/app_state.dart';
import 'package:pockettally/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<AppState> fresh() async {
    SharedPreferences.setMockInitialValues({});
    return AppState(await SharedPreferences.getInstance());
  }

  test('the PIN is stored only as a salted hash', () async {
    final state = await fresh();
    expect(state.appLockOn, isFalse);
    await state.setPin('1234');
    expect(state.appLockOn, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pin_hash'), isNot(contains('1234')));
    expect(AppState.hashPin('1234', 'a'), AppState.hashPin('1234', 'a'));
    expect(AppState.hashPin('1234', 'a'), isNot(AppState.hashPin('1234', 'b')));
  });

  test('right and wrong PINs, and a pause after five wrong ones', () async {
    final state = await fresh();
    await state.setPin('2580');
    expect(await state.tryPin('0000'), isFalse);
    expect(await state.tryPin('2580'), isTrue);
    for (var i = 0; i < AppState.pinTriesBeforeWait; i++) {
      expect(await state.tryPin('1111'), isFalse);
    }
    expect(state.pinWaitLeft, greaterThan(Duration.zero));
    // While waiting, even the right PIN is refused.
    expect(await state.tryPin('2580'), isFalse);
    await state.removePin();
    expect(state.appLockOn, isFalse);
  });

  test('lock and reminder texts in every language', () {
    for (final lang in kLanguages) {
      final l = lookupAppLocalizations(Locale(lang.code));
      expect(l.lockAfterMinutes(5), contains(RegExp(r'5|৫')), reason: lang.code);
      expect(l.tooManyTries('30'), contains('30'), reason: lang.code);
      expect(l.reminderBody, isNotEmpty, reason: lang.code);
    }
  });

  test('reminder settings', () async {
    final state = await fresh();
    expect(state.reminderOn, isFalse);
    expect(state.reminderMinutes, 21 * 60);
    await state.setReminder(on: true, minutes: 20 * 60 + 30);
    expect(state.reminderOn, isTrue);
    expect(state.reminderMinutes, 1230);
  });
}
