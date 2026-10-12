import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Four dots and a number pad for typing a PIN. On a computer the number
/// keys and Backspace work too. Calls [onComplete] when four digits are in,
/// then clears itself.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    required this.onComplete,
    this.message,
    this.isError = false,
    this.enabled = true,
    this.footer,
  });

  static const int length = 4;

  final String title;

  /// A line under the title, e.g. "Wrong PIN".
  final String? message;
  final bool isError;
  final bool enabled;
  final ValueChanged<String> onComplete;

  /// Shown below the pad, e.g. "Forgot PIN?".
  final Widget? footer;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _digits = '';
  final FocusNode _focus = FocusNode(debugLabel: 'pin');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _add(String d) {
    if (!widget.enabled || _digits.length >= PinPad.length) return;
    setState(() => _digits += d);
    if (_digits.length == PinPad.length) {
      final pin = _digits;
      // Let the last dot show for a moment.
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() => _digits = '');
        widget.onComplete(pin);
      });
    }
  }

  void _back() {
    if (_digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _back();
      return KeyEventResult.handled;
    }
    final c = event.character;
    if (c != null && c.length == 1 && '0123456789'.contains(c)) {
      _add(c);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget key(String label) => _PadKey(
          onTap: widget.enabled ? () => _add(label) : null,
          child: Text(label,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        );
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40),
            child: widget.message == null
                ? null
                : Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: widget.isError
                            ? scheme.error
                            : scheme.onSurfaceVariant),
                  ),
          ),
          Semantics(
            label: '${_digits.length} / ${PinPad.length}',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < PinPad.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _digits.length
                          ? scheme.onSurface
                          : Colors.transparent,
                      border: Border.all(color: scheme.outline, width: 1.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          // Phone-style number pad; always left-to-right.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final row in const [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [for (final d in row) key(d)],
                  ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 88, height: 76),
                    key('0'),
                    _PadKey(
                      onTap: widget.enabled ? _back : null,
                      plain: true,
                      child: Icon(Icons.backspace_outlined,
                          semanticLabel: MaterialLocalizations.of(context)
                              .deleteButtonTooltip),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.footer != null) ...[
            const SizedBox(height: 12),
            widget.footer!,
          ],
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.child, this.onTap, this.plain = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool plain;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: SizedBox(
        width: 68,
        height: 64,
        child: Material(
          color: plain ? Colors.transparent : scheme.surfaceContainerHigh,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Opacity(opacity: onTap == null ? 0.4 : 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
