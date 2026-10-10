import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../utils/amount_parser.dart';

/// Asks for an amount. Returns minor units, or null if cancelled.
/// Typing simple math like 500+250 works too.
Future<int?> askAmount(
  BuildContext context,
  AppState state, {
  required String title,
  String label = 'Amount',
  String? helper,
  int? initialMinor,
  int? maxMinor,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _AmountDialog(
      state: state,
      title: title,
      label: label,
      helper: helper,
      initialMinor: initialMinor,
      maxMinor: maxMinor,
    ),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({
    required this.state,
    required this.title,
    required this.label,
    this.helper,
    this.initialMinor,
    this.maxMinor,
  });

  final AppState state;
  final String title;
  final String label;
  final String? helper;
  final int? initialMinor;
  final int? maxMinor;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialMinor;
    _controller = TextEditingController(
        text: initial == null ? '' : (initial / 100).toStringAsFixed(2));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final v = evaluateAmount(_controller.text);
    final minor = v == null ? 0 : (v * 100).round();
    if (minor <= 0) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    final max = widget.maxMinor;
    if (max != null && minor > max) {
      setState(() => _error = 'Can be at most ${widget.state.formatMoney(max)}');
      return;
    }
    Navigator.of(context).pop(minor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,+\-*/×÷()]')),
        ],
        decoration: InputDecoration(
          labelText: widget.label,
          helperText: widget.helper,
          prefixText: '${widget.state.currency.symbol} ',
          errorText: _error,
          border: const OutlineInputBorder(),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
