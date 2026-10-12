import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'auto_backup.dart';
import 'l10n/l10n.dart';
import 'photo_store.dart';
import 'platform.dart';
import 'screens/lock_screen.dart';
import 'screens/root_shell.dart';
import 'screens/startup_error_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  late final AppState state;
  try {
    initDatabaseFactory();
    // Month and day names for every language (used by DateFormat).
    await initializeDateFormatting();
    final prefs = await SharedPreferences.getInstance();
    state = AppState(prefs);
    await state.load();
  } catch (error, stack) {
    // Never hang on the splash screen: show what went wrong instead, so
    // it can be reported. The data is not touched.
    runApp(StartupErrorApp(error: error, stack: stack));
    return;
  }
  // Extras that must never stop the app from opening.
  try {
    // Salary, rent and other repeating entries that became due.
    await state.runRecurring();
  } catch (e) {
    debugPrint('Recurring entries skipped: $e');
  }
  try {
    await PhotoStore.init();
    // Bill photos of deleted entries (kept until now for Undo).
    // Skipped when there are no entries at all, to be safe.
    if (state.entries.isNotEmpty) {
      await PhotoStore.cleanOrphans(
          state.entries.map((e) => e.photo).whereType<String>().toSet());
    }
  } catch (e) {
    debugPrint('Photo folder not ready: $e');
  }
  runApp(PocketTallyApp(state: state));
  // Weekly (or daily) backup file, if it is due.
  AutoBackup.runIfDue(state).catchError((_) => false);
}

class PocketTallyApp extends StatelessWidget {
  const PocketTallyApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final language = state.languageCode;
        // Dates (DateFormat) follow the app language.
        Intl.defaultLocale = language;
        return MaterialApp(
          // A fresh start (welcome screen, or after "Reset the app") also
          // clears every open page.
          key: ValueKey(state.onboarded),
          title: 'PocketTally',
          debugShowCheckedModeBanner: false,
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          themeMode: state.themeMode,
          theme: buildTheme(Brightness.light, state.palette),
          darkTheme: buildTheme(Brightness.dark, state.palette),
          home: state.onboarded
              ? RootShell(state: state)
              : WelcomeScreen(state: state),
          // The PIN screen covers every page while the app is locked.
          builder: (context, child) =>
              AppLockGate(state: state, child: child ?? const SizedBox()),
        );
      },
    );
  }
}
