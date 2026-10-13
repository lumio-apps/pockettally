import 'package:flutter/widgets.dart';

import '../models.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';

/// `context.l10n.save` instead of `AppLocalizations.of(context).save`.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

/// A language the app is translated into.
class AppLanguage {
  const AppLanguage(this.code, this.nativeName, this.englishName);

  final String code;

  /// The name in the language itself, e.g. "हिन्दी".
  final String nativeName;
  final String englishName;
}

const List<AppLanguage> kLanguages = [
  AppLanguage('en', 'English', 'English'),
  AppLanguage('hi', 'हिन्दी', 'Hindi'),
  AppLanguage('hy', 'Հայերեն', 'Armenian'),
  AppLanguage('zh', '中文', 'Chinese'),
  AppLanguage('es', 'Español', 'Spanish'),
  AppLanguage('ar', 'العربية', 'Arabic'),
  AppLanguage('fr', 'Français', 'French'),
  AppLanguage('bn', 'বাংলা', 'Bengali'),
  AppLanguage('pt', 'Português', 'Portuguese'),
  AppLanguage('ru', 'Русский', 'Russian'),
  AppLanguage('ur', 'اردو', 'Urdu'),
  AppLanguage('id', 'Bahasa Indonesia', 'Indonesian'),
  AppLanguage('ja', '日本語', 'Japanese'),
  AppLanguage('gu', 'ગુજરાતી', 'Gujarati'),
  AppLanguage('ta', 'தமிழ்', 'Tamil'),
  AppLanguage('te', 'తెలుగు', 'Telugu'),
  AppLanguage('mr', 'मराठी', 'Marathi'),
  AppLanguage('kn', 'ಕನ್ನಡ', 'Kannada'),
  AppLanguage('ml', 'മലയാളം', 'Malayalam'),
  AppLanguage('pa', 'ਪੰਜਾਬੀ', 'Punjabi'),
];

AppLanguage languageByCode(String code) =>
    kLanguages.firstWhere((l) => l.code == code, orElse: () => kLanguages.first);

/// Built-in categories are stored with their English name and shown in the
/// app's language. Categories the user created or renamed show as typed.
String categoryLabel(AppLocalizations l, String name) {
  switch (name) {
    case 'Food':
      return l.catFood;
    case 'Rent':
      return l.catRent;
    case 'Travel':
      return l.catTravel;
    case 'Shopping':
      return l.catShopping;
    case 'Bills':
      return l.catBills;
    case 'Health':
      return l.catHealth;
    case 'Entertainment':
      return l.catEntertainment;
    case 'Education':
      return l.catEducation;
    case kOtherCategory:
      return l.catOther;
    case 'Salary':
      return l.catSalary;
    case 'Business':
      return l.catBusiness;
    case 'Gift':
      return l.catGift;
    default:
      return name;
  }
}

String periodName(AppLocalizations l, IncomePeriod p) {
  switch (p) {
    case IncomePeriod.daily:
      return l.daily;
    case IncomePeriod.weekly:
      return l.weekly;
    case IncomePeriod.monthly:
      return l.monthly;
  }
}

String periodIncomeLabel(AppLocalizations l, IncomePeriod p) {
  switch (p) {
    case IncomePeriod.daily:
      return l.dailyIncome;
    case IncomePeriod.weekly:
      return l.weeklyIncome;
    case IncomePeriod.monthly:
      return l.monthlyIncome;
  }
}

/// Backup errors are thrown as FormatException with one of these codes.
String backupErrorMessage(AppLocalizations l, String code) {
  switch (code) {
    case 'unreadable':
      return l.fileUnreadable;
    case 'not_ours':
      return l.backupNotOurs;
    case 'too_new':
      return l.backupTooNew;
    case 'damaged':
      return l.backupDamaged;
    default:
      return l.backupInvalid;
  }
}
