import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'l10n/l10n.dart';
import 'photo_store.dart';
import 'platform.dart';
import 'screens/root_shell.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactory();
  // Month and day names for every language (used by DateFormat).
  await initializeDateFormatting();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs);
  await state.load();
  // Salary, rent and other repeating entries that became due.
  await state.runRecurring();
  await PhotoStore.init();
  runApp(PocketTallyApp(state: state));
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
        );
      },
    );
  }
}
