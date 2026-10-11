import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../photo_store.dart';
import '../platform.dart';
import '../theme.dart';
import '../utils/amount_parser.dart' show isCalculation;
import '../widgets/entry_tile.dart'
    show kIncomeColor, kExpenseColor, deleteEntryWithUndo;
import 'categories_screen.dart';
import 'photo_view_screen.dart';

/// Add a new entry, or edit an existing one when [entry] is given.
/// The amount is typed with the device's own keyboard (phone keyboard or
/// computer keyboard). Simple math like 120+45 also works. Enter saves.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    super.key,
    required this.state,
    this.entry,
    this.initialType = EntryType.expense,
    this.embedded = false,
    this.initialDate,
  });

  final AppState state;
  final Entry? entry;
  final EntryType initialType;

  /// Shown as the "quick add" panel next to Home on wide windows: it stays
  /// open and clears itself after saving instead of closing.
  final bool embedded;

  /// Date for a new entry (default today), e.g. from the calendar.
  final DateTime? initialDate;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  late final TextEditingController _noteController;
  late final TextEditingController _tagsController;

  /// Repeat this new entry (null = only once).
  RepeatEvery? _repeat;

  late EntryType _type;
  late String _category;
  late DateTime _date;
  IncomePeriod _period = IncomePeriod.monthly;
  late final TextEditingController _amountController;
  final FocusNode _amountFocus = FocusNode(debugLabel: 'amount');
  String? _photo;

  bool get _isEditing => widget.entry != null;

  List<String> get _categories {
    final names = widget.state
        .categoriesFor(_type, includeHidden: false, keep: widget.entry?.category)
        .map((c) => c.name)
        .toList();
    return names.isEmpty ? [kOtherCategory] : names;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _type = e?.type ?? widget.initialType;
    _date = e?.date ?? widget.initialDate ?? DateTime.now();
    _category = e?.category ?? _categories.first;
    _period = e?.period ?? IncomePeriod.monthly;
    _photo = e?.photo;
    // 320.00 -> "320", 12.50 -> "12.5" (or "12,5")
    _amountController = TextEditingController(
        text: e == null ? '' : widget.state.amountInput(e.amountMinor));
    _noteController = TextEditingController(text: e?.note ?? '');
    _tagsController = TextEditingController(text: e?.tags.join(', ') ?? '');
    if (widget.embedded) widget.state.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    // The panel stays open, so it follows category changes made elsewhere.
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (widget.embedded) widget.state.removeListener(_onStateChanged);
    _amountFocus.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  /// "120+45" -> "165" when the user taps the result.
  void _applyResult() {
    final minor = widget.state.parseMinor(_amountController.text);
    if (minor == null) return;
    setState(() => _amountController.text = widget.state.amountInput(minor));
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
    final l = context.l10n;
    // Desktop has no camera: go straight to the file dialog.
    final camera = isDesktop
        ? false
        : await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l.takePhoto),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.chooseFromGallery),
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
          SnackBar(content: Text(l.couldNotAddPhoto)));
    }
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteEntryQuestion),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.delete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    Navigator.of(context).pop();
    await deleteEntryWithUndo(messenger, l, widget.state, widget.entry!);
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final amount = widget.state.parseMinor(_amountController.text);
    if (amount == null || amount <= 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.enterAmountAboveZero)));
      return;
    }
    final entry = Entry(
      id: widget.entry?.id,
      type: _type,
      amountMinor: amount,
      category: _category,
      date: _date,
      note: _noteController.text.trim(),
      period: _type == EntryType.income ? _period : null,
      photo: _photo,
      tags: parseTags(_tagsController.text),
    );
    if (_isEditing) {
      await widget.state.updateEntry(entry);
    } else {
      await widget.state.addEntry(entry);
      if (_repeat != null) {
        await widget.state.addRecurringFrom(entry, _repeat!);
      }
    }
    final warning = widget.state.budgetWarningFor(entry, l);
    if (widget.embedded) {
      // Ready for the next entry; type, category and date stay.
      if (mounted) {
        setState(() {
          _amountController.clear();
          _photo = null;
          _repeat = null;
          _noteController.clear();
          _tagsController.clear();
        });
        _amountFocus.requestFocus();
      }
    } else if (mounted) {
      Navigator.of(context).pop();
    }
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

  /// Saves what is in the form as a favorite for one-tap adding on Home.
  Future<void> _saveFavorite() async {
    final messenger = ScaffoldMessenger.of(context);
    final l = context.l10n;
    final amount = widget.state.parseMinor(_amountController.text);
    if (amount == null || amount <= 0) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.enterAmountAboveZero)));
      return;
    }
    await widget.state.addFavorite(Favorite(
      type: _type,
      amountMinor: amount,
      category: _category,
      note: _noteController.text.trim(),
      period: _type == EntryType.income ? _period : null,
    ));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.addedToFavorites)));
  }

  void _addTag(String tag) {
    final tags = parseTags(_tagsController.text);
    if (tags.contains(tag)) return;
    setState(() => _tagsController.text = [...tags, tag].join(', '));
  }

  String _repeatLabel(AppLocalizations l, RepeatEvery? r) {
    switch (r) {
      case null:
        return l.repeatNever;
      case RepeatEvery.daily:
        return l.everyDay;
      case RepeatEvery.weekly:
        return l.everyWeek;
      case RepeatEvery.monthly:
        return l.everyMonth;
      case RepeatEvery.yearly:
        return l.everyYear;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    final isIncome = _type == EntryType.income;
    final typedTags = parseTags(_tagsController.text);
    final tagSuggestions = widget.state.allTags
        .where((t) => !typedTags.contains(t))
        .take(8)
        .toList();
    final amountColor = isIncome ? kIncomeColor : kExpenseColor;
    final categoryNames = _categories;
    if (!categoryNames.contains(_category)) {
      // The category was renamed or deleted in the meantime.
      _category = categoryNames.contains(kOtherCategory)
          ? kOtherCategory
          : categoryNames.first;
    }
    final result = isCalculation(_amountController.text)
        ? widget.state.parseMinor(_amountController.text)
        : null;
    final photoFile = _photo == null ? null : PhotoStore.file(_photo!);

    final amountStyle = TextStyle(
      fontSize: 44,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      color: amountColor,
    );

    return Scaffold(
      backgroundColor: widget.embedded ? theme.colorScheme.surface : null,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        backgroundColor: widget.embedded ? theme.colorScheme.surface : null,
        title: Text(_isEditing ? l.editEntry : l.newEntry),
        actions: [
          IconButton(
            tooltip: l.saveAsFavorite,
            icon: const Icon(Icons.star_outline),
            onPressed: _saveFavorite,
          ),
          if (_isEditing)
            IconButton(
              tooltip: l.delete,
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
                    segments: [
                      ButtonSegment(
                          value: EntryType.expense, label: Text(l.expense)),
                      ButtonSegment(
                          value: EntryType.income, label: Text(l.income)),
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
                    child: Text(l.amount, style: theme.textTheme.bodySmall),
                  ),
                  // Typed with the device keyboard; a new entry starts here.
                  TextField(
                    controller: _amountController,
                    focusNode: _amountFocus,
                    autofocus: !_isEditing,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r"[0-9.,+\-*/×÷xX() ']")),
                    ],
                    style: amountStyle,
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: amountStyle.copyWith(
                          color: amountColor.withValues(alpha: 0.35)),
                      prefixText: '${widget.state.currency.symbol} ',
                      prefixStyle: amountStyle,
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _save(),
                  ),
                  SizedBox(
                    height: 32,
                    child: result == null
                        ? null
                        : Center(
                            child: TextButton(
                              onPressed: _applyResult,
                              child: Text(
                                  '= ${widget.state.formatMoney(result)}'),
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
                          label: Text(categoryLabel(l, c)),
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
                        label: Text(l.manage),
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
                    Text(l.thisIncomeIs, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    SegmentedButton<IncomePeriod>(
                      segments: [
                        ButtonSegment(
                            value: IncomePeriod.daily, label: Text(l.daily)),
                        ButtonSegment(
                            value: IncomePeriod.weekly, label: Text(l.weekly)),
                        ButtonSegment(
                            value: IncomePeriod.monthly,
                            label: Text(l.monthly)),
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
                          label: Text(DateFormat.MMMEd().format(_date)),
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
                                label: Text(l.billPhoto),
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
                                              SizedBox(
                                            height: 48,
                                            child: Center(
                                                child: Text(l.photoMissing)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: l.removePhoto,
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
                      hintText: l.noteOptional,
                      prefixIcon: const Icon(Icons.edit_note),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _tagsController,
                    decoration: InputDecoration(
                      hintText: l.tagsHint,
                      prefixIcon: const Icon(Icons.sell_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (tagSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final t in tagSuggestions)
                          ActionChip(
                            label: Text('#$t'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _addTag(t),
                          ),
                      ],
                    ),
                  ],
                  if (!_isEditing) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<RepeatEvery?>(
                      key: ValueKey('repeat-$_repeat'),
                      initialValue: _repeat,
                      decoration: InputDecoration(
                        labelText: l.repeat,
                        prefixIcon: const Icon(Icons.repeat),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      items: [
                        for (final r in <RepeatEvery?>[
                          null,
                          ...RepeatEvery.values,
                        ])
                          DropdownMenuItem(
                            value: r,
                            child: Text(_repeatLabel(l, r)),
                          ),
                      ],
                      onChanged: (r) => setState(() => _repeat = r),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(_isEditing
                      ? l.saveChanges
                      : isIncome
                          ? l.saveIncome
                          : l.saveExpense),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
