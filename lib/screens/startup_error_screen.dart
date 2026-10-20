import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shown instead of the app when it cannot start (for example the
/// database cannot be opened). The user's data is left as it is.
/// Plain English on purpose: translations may not be loaded yet.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.error, required this.stack});

  final Object error;
  final StackTrace stack;

  @override
  Widget build(BuildContext context) {
    final details = 'PocketTally could not start\n\n$error\n\n$stack';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.error_outline, size: 48, color: Color(0xFFC0392B)),
                const SizedBox(height: 16),
                const Text(
                  'PocketTally could not start',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your data has not been changed. Please copy the details '
                  'below and report them at github.com/lumio-apps/pockettally/issues. '
                  'Do not uninstall the app or clear its storage, or your '
                  'data will be lost.',
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy details'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: details));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(duration: Duration(seconds: 3), content: Text('Copied')));
                    }
                  },
                ),
                const SizedBox(height: 16),
                SelectableText(
                  details,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
