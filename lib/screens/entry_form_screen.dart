import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../models.dart';
import '../photo_store.dart';
import '../theme.dart';
import '../utils/amount_parser.dart';
import '../widgets/entry_tile.dart'
    show kIncomeColor, kExpenseColor, deleteEntryWithUndo;
import 'categories_screen.dart';
import 'photo_view_screen.dart';

/// Add a new entry, or edit an existing one when [entry] is given.
/// The amount is typed on the app's own keypad, which also calculates.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    super.key,
    required this.state,
    this.entry,
    this.initialType = EntryType.expense,
  });

  final AppState state;
  final Entry? entry;
  final EntryType initialType;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  late final TextEditingController _noteController;

  late EntryType _type;
  late String _category;
  late DateTime _date;
  IncomePeriod _period = IncomePeriod.monthly;
  String _input = '';
  String? _photo;

  bool get _isEditing => widget.entry != null;

  List<String> get _categories {
    final names =
        widget.state.categoriesFor(_type).map((c) => c.name).toList();
    return names.isEmpty ? [kOtherCategory] : names;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _type = e?.type ?? widget.initialType;
    _date = e?.date ?? DateTime.now();
    _category = e?.category ?? _categories.first;
    _period = e?.period ?? IncomePeriod.monthly;
    _photo = e?.photo;
    if (e != null) {
      // 320.00 -> "320", 12.50 -> "12.5"
      _input = (e.amountMinor / 100)
          .toStringAsFixed(2)
          .replaceFirst(RegExp(r'\.?0+$'), '');
    }
    _noteController = TextEditingController(text: e?.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // ---- keypad ----

  static const _operators = ['+', '-', '×', '÷'];

  void _press(String key) {
    setState(() {
      if (key == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
        return;
      }
      final last = _input.isEmpty ? '' : _input[_input.length - 1];
      if (_operators.contains(key)) {
        if (_input.isEmpty) return;
        // Replace a trailing operator instead of stacking two.
        if (_operators.contains(last)) {
          _input = _input.substring(0, _input.length - 1);
        }
        _input += key;
        return;
      }
      if (key == '.') {
        final lastNumber = _input.split(RegExp(r'[-+×÷]')).last;
        if (lastNumber.contains('.')) return;
        if (lastNumber.isEmpty) _input += '0';
      }
      if (_input.length >= 24) return;
      _input += key;
    });
  }

  void _applyResult() {
    final v = evaluateAmount(_input);
    if (v == null) return;
    setState(() {
      _input = v.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
    });
  }

  // ---- actions ----

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addPhoto() async {
    final camera = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    );
    if (camera == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = await PhotoStore.pick(camera: camera);
      if (name != null && mounted) setState(() => _photo = name);
    } catch (_) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not add the photo.')));
    }
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pop();
    await deleteEntryWithUndo(messenger, widget.state, widget.entry!);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final value = evaluateAmount(_input);
    if (value == null || (value * 100).round() <= 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Enter an amount greater than 0')));
      return;
    }
    final entry = Entry(
      id: widget.entry?.id,
      type: _type,
      amountMinor: (value * 100).round(),
      category: _category,
      date: _date,
      note: _noteController.text.trim(),
      period: _type == EntryType.income ? _period : null,
      photo: _photo,
    );
    if (_isEditing) {
      await widget.state.updateEntry(entry);
    } else {
      await widget.state.addEntry(entry);
    }
    final warning = widget.state.budgetWarningFor(entry);
    if (mounted) Navigator.of(context).pop();
    if (warning != null) {
      messenger.showSnackBar(SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: kAccent),
            const SizedBox(width: 12),
            Expanded(child: Text(warning)),
          ],
        ),
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = _type == EntryType.income;
    final amountColor = isIncome ? kIncomeColor : kExpenseColor;
    final categoryNames = _categories;
    if (!categoryNames.contains(_category)) {
      // The category was renamed or deleted in the meantime.
      _category = categoryNames.contains(kOtherCategory)
          ? kOtherCategory
          : categoryNames.first;
    }
    final result = isCalculation(_input) ? evaluateAmount(_input) : null;
    final photoFile = _photo == null ? null : PhotoStore.file(_photo!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit entry' : 'New entry'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  SegmentedButton<EntryType>(
                    segments: const [
                      ButtonSegment(
                          value: EntryType.expense, label: Text('Expense')),
                      ButtonSegment(
                          value: EntryType.income, label: Text('Income')),
                    ],
                    showSelectedIcon: false,
                    selected: {_type},
                    onSelectionChanged: (s) => setState(() {
                      _type = s.first;
                      _category = _categories.first;
                    }),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('Amount', style: theme.textTheme.bodySmall),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${widget.state.currency.symbol} ${_input.isEmpty ? '0' : _input}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: amountColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: result == null
                        ? null
                        : Center(
                            child: TextButton(
                              onPressed: _applyResult,
                              child: Text(
                                  '= ${widget.state.currency.symbol} ${result.toStringAsFixed(2)}'),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in categoryNames)
                        ChoiceChip(
                          label: Text(c),
                          selected: c == _category,
                          avatar: CircleAvatar(
                            backgroundColor:
                                widget.state.colorFor(c, _type),
                          ),
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.tune, size: 18),
                        label: const Text('Manage'),
                        onPressed: () async {
                          await Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => CategoriesScreen(
                              state: widget.state,
                              initialType: _type,
                            ),
                          ));
                          if (mounted) setState(() {});
                        },
                      ),
                    ],
                  ),
                  if (isIncome) ...[
                    const SizedBox(height: 14),
                    Text('This income is', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    SegmentedButton<IncomePeriod>(
                      segments: const [
                        ButtonSegment(
                            value: IncomePeriod.daily, label: Text('Daily')),
                        ButtonSegment(
                            value: IncomePeriod.weekly, label: Text('Weekly')),
                        ButtonSegment(
                            value: IncomePeriod.monthly,
                            label: Text('Monthly')),
                      ],
                      showSelectedIcon: false,
                      selected: {_period},
                      onSelectionChanged: (s) =>
                          setState(() => _period = s.first),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48)),
                          icon: const Icon(Icons.calendar_today_outlined,
                              size: 18),
                          label: Text(DateFormat('EEE, d MMM').format(_date)),
                          onPressed: _pickDate,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: photoFile == null
                            ? OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(0, 48)),
                                icon: const Icon(Icons.receipt_long_outlined,
                                    size: 18),
                                label: const Text('Bill photo'),
                                onPressed: _addPhoto,
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PhotoViewScreen(file: photoFile),
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.file(
                                          photoFile,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stack) =>
                                              const SizedBox(
                                            height: 48,
                                            child: Center(
                                                child: Text('Photo missing')),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove photo',
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        setState(() => _photo = null),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Note (optional)',
                      prefixIcon: const Icon(Icons.edit_note),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
            _Keypad(onKey: _press),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(_isEditing
                      ? 'Save changes'
                      : isIncome
                          ? 'Save income'
                          : 'Save expense'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  static const _rows = [
    ['7', '8', '9', '÷'],
    ['4', '5', '6', '×'],
    ['1', '2', '3', '-'],
    ['.', '0', '⌫', '+'],
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          for (final row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: _key(row[i], scheme)),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _key(String k, ColorScheme scheme) {
    final isOperator = ['+', '-', '×', '÷'].contains(k);
    final label = k == '-' ? '−' : k;
    return SizedBox(
      height: 50,
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: const Size(0, 50),
          backgroundColor: isOperator
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          foregroundColor:
              isOperator ? scheme.onPrimaryContainer : scheme.onSurface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => onKey(k),
        child: k == '⌫'
            ? const Icon(Icons.backspace_outlined, semanticLabel: 'Delete digit')
            : Text(label,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
