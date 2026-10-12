import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../utils/lock_guard.dart';
import '../widgets/app_logo.dart';
import '../widgets/pin_pad.dart';

/// Covers the app with the PIN screen when the app lock is on: at start and
/// after the app was in the background for the chosen time. The app below
/// stays as it was, so nothing typed is lost.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.state, required this.child});

  final AppState state;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> {
  late bool _locked = widget.state.appLockOn;
  DateTime? _leftAt;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        // Pickers and save dialogs leave the app on purpose: no lock then.
        if (!LockGuard.active) _leftAt ??= DateTime.now();
      },
      onShow: _checkLock,
      onResume: _checkLock,
    );
  }

  void _checkLock() {
    final left = _leftAt;
    _leftAt = null;
    if (left == null || !widget.state.appLockOn) return;
    final away = DateTime.now().difference(left);
    if (away.inSeconds >= widget.state.lockAfterSeconds && mounted) {
      setState(() => _locked = true);
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final show = _locked && widget.state.appLockOn;
    return Stack(
      children: [
        // While locked, the app below gets no keyboard focus and is hidden
        // from screen readers.
        ExcludeFocus(
          excluding: show,
          child: ExcludeSemantics(excluding: show, child: widget.child),
        ),
        if (show)
          Positioned.fill(
            child: LockScreen(
              state: widget.state,
              onUnlocked: () => setState(() => _locked = false),
            ),
          ),
      ],
    );
  }
}

/// "Enter your PIN", with a pause after too many wrong tries and a way to
/// reset the app when the PIN is forgotten.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.state, required this.onUnlocked});

  final AppState state;
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String? _error;
  bool _confirmReset = false;
  bool _busy = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startTickerIfWaiting();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Updates the "wait N seconds" text every second.
  void _startTickerIfWaiting() {
    _ticker?.cancel();
    if (widget.state.pinWaitLeft <= Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (widget.state.pinWaitLeft <= Duration.zero) {
        t.cancel();
        setState(() => _error = null);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _check(String pin) async {
    final l = context.l10n;
    if (await widget.state.tryPin(pin)) {
      widget.onUnlocked();
      return;
    }
    if (!mounted) return;
    setState(() => _error = l.wrongPin);
    _startTickerIfWaiting();
  }

  Future<void> _reset() async {
    setState(() => _busy = true);
    try {
      await widget.state.resetEverything();
      widget.onUnlocked();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final wait = widget.state.pinWaitLeft;
    final waiting = wait > Duration.zero;
    // No Navigator above this screen, so the reset question is shown in
    // place instead of in a dialog.
    final Widget body = _confirmReset
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.warning_amber_rounded,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(l.resetAppTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(l.resetAppBody,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError),
                onPressed: _busy ? null : _reset,
                child: Text(l.resetApp),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    _busy ? null : () => setState(() => _confirmReset = false),
                child: Text(l.cancel),
              ),
            ],
          )
        : PinPad(
            title: l.enterPin,
            message: waiting
                ? l.tooManyTries((wait.inSeconds + 1).toString())
                : _error ?? l.appLocked,
            isError: waiting || _error != null,
            enabled: !waiting,
            onComplete: _check,
            footer: TextButton(
              onPressed: () => setState(() => _confirmReset = true),
              child: Text(l.forgotPin),
            ),
          );

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AppLogo(size: 56),
                  const SizedBox(height: 20),
                  body,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What [PinSetupScreen] is for.
enum PinSetupMode {
  /// Choose a new PIN (typed twice). Returns the PIN.
  create,

  /// Type the current PIN. Returns 'ok' when it was right.
  verify,
}

/// A full screen for choosing a PIN or confirming the current one.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.state, required this.mode});

  final AppState state;
  final PinSetupMode mode;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String? _first;
  String? _error;

  Future<void> _onPin(String pin) async {
    final l = context.l10n;
    if (widget.mode == PinSetupMode.verify) {
      if (await widget.state.tryPin(pin)) {
        if (mounted) Navigator.of(context).pop('ok');
      } else if (mounted) {
        setState(() => _error = widget.state.pinWaitLeft > Duration.zero
            ? l.tooManyTries(
                (widget.state.pinWaitLeft.inSeconds + 1).toString())
            : l.wrongPin);
      }
      return;
    }
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
    } else if (_first == pin) {
      Navigator.of(context).pop(pin);
    } else {
      setState(() {
        _first = null;
        _error = l.pinsDontMatch;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final verify = widget.mode == PinSetupMode.verify;
    final title = verify
        ? l.currentPin
        : _first == null
            ? l.createPin
            : l.confirmPin;
    return Scaffold(
      appBar: AppBar(title: Text(l.appLock)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: PinPad(
                // A new key restarts the pad between the two steps.
                key: ValueKey('$verify-${_first != null}'),
                title: title,
                message: _error ?? (verify ? null : l.pinForgetNote),
                isError: _error != null,
                onComplete: _onPin,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
