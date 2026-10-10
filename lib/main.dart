import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'photo_store.dart';
import 'screens/root_shell.dart';
import 'screens/welcome_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = AppState(prefs);
  await state.load();
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
        return MaterialApp(
          title: 'PocketTally',
          debugShowCheckedModeBanner: false,
          themeMode: state.themeMode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: state.onboarded
              ? RootShell(state: state)
              : WelcomeScreen(state: state),
        );
      },
    );
  }
}
