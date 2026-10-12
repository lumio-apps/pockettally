import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../photo_store.dart';
import '../platform.dart';
import '../split.dart';
import '../theme.dart';
import '../utils/amount_parser.dart' show isCalculation;
import '../widgets/entry_tile.dart'
    show kIncomeColor, kExpenseColor, deleteEntryWithUndo;
import 'categories_screen.dart';
import 'photo_view_screen.dart';
import 'split_screen.dart';

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
    this.template,
  });

  /// "Duplicate": a new entry filled in like this one (dated today, without
  /// its bill photo).
  final Entry? template;

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

  /// Time of day in minutes; null for old entries saved without one.
  int? _minutes;
  IncomePeriod _period = IncomePeriod.monthly;
  late final TextEditingController _amountController;
  final FocusNode _amountFocus = FocusNode(debugLabel: 'amount');
  String? _photo;

  /// A new expense shared with other people (null = not split).
  SplitPlan? _split;

  bool get _isEditing => widget.entry != null;

  /// The split, when it applies: only new expenses are split.
  SplitPlan? get _activeSplit =>
      !_isEditing && _type == EntryType.expense ? _split : null;

  /// Shares are whole units when amounts are shown without decimals.
  int get _splitUnit => widget.state.money.decimals == 0 ? 100 : 1;

  List<String> get _categories {
    final names = widget.state
        .categoriesFor(_type, includeHidden: false, keep: widget.entry?.category)
        .map((c) => c.name)
        .toList();
    return names.isEmpty ? [kOtherCategory] : names;
  }

  /// The category used last time for this type, else the first one.
  String _defaultCategory() {
    final names = _categories;
    final last = widget.state.lastCategory(_type);
    return last != null && names.contains(last) ? last : names.first;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.entry ?? widget.template;
    _type = e?.type ?? widget.initialType;
    _date = widget.entry?.date ?? widget.initialDate ?? DateTime.now();
    _category = e?.category ?? _defaultCategory();
    _period = e?.period ?? IncomePeriod.monthly;
    _photo = widget.entry?.photo;
    final now = DateTime.now();
    _minutes = widget.entry != null
        ? widget.entry!.minutes
        : now.hour * 60 + now.minute;
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

  Future<void> _pickTime() async {
    final m = _minutes ?? DateTime.now().hour * 60 + DateTime.now().minute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (picked != null) {
      setState(() => _minutes = picked.hour * 60 + picked.minute);
    }
  }

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

  /// Opens the split screen for the amount typed so far.
  Future<void> _openSplit() async {
    final l = context.l10n;
    final amount = widget.state.parseMinor(_amountController.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.enterAmountAboveZero)));
      _amountFocus.requestFocus();
      return;
    }
    final plan = await Navigator.of(context).push<SplitPlan>(
      MaterialPageRoute(
        builder: (_) => SplitBillScreen(
          state: widget.state,
          totalMinor: amount,
          initial: _split,
        ),
      ),
    );
    if (plan == null || !mounted) return;
    setState(() {
      _split = plan;
      // A split bill is not repeated.
      _repeat = null;
    });
  }

  /// "Dinner · Split bill, total ₹ 1,200".
  String _splitEntryNote(AppLocalizations l, String note, int totalMinor) {
    final split = l.splitEntryNote(widget.state.formatMoney(totalMinor));
    return note.isEmpty ? split : '$note · $split';
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
    // A split bill keeps only the user's share as the expense; the rest
    // goes to Lend & Borrow.
    final split = _activeSplit;
    List<int>? shares;
    if (split != null) {
      shares = split.sharesFor(amount, unit: _splitUnit);
      if (shares == null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.splitSharesWrong)));
        return;
      }
    }
    final note = _noteController.text.trim();
    final entry = Entry(
      id: widget.entry?.id,
      type: _type,
      amountMinor: shares == null ? amount : shares[0],
      category: _category,
      date: _date,
      minutes: _minutes,
      note: shares == null ? note : _splitEntryNote(l, note, amount),
      period: _type == EntryType.income ? _period : null,
      photo: _photo,
      tags: parseTags(_tagsController.text),
    );
    var debtsAdded = 0;
    if (_isEditing) {
      await widget.state.updateEntry(entry);
    } else {
      // With a custom split the user's own share can be 0.
      if (entry.amountMinor > 0) await widget.state.addEntry(entry);
      await widget.state.setLastCategory(_type, _category);
      if (split != null && shares != null) {
        final what = note.isNotEmpty ? note : categoryLabel(l, _category);
        final debts = split.debtsFor(shares, _date, l.splitDebtNote(what));
        await widget.state.addDebts(debts);
        debtsAdded = debts.length;
      } else if (_repeat != null) {
        await widget.state.addRecurringFrom(entry, _repeat!);
      }
    }
    final warning = entry.amountMinor > 0
        ? widget.state.budgetWarningFor(entry, l)
        : null;
    if (widget.embedded) {
      // Ready for the next entry; type, category and date stay.
      if (mounted) {
        setState(() {
          _amountController.clear();
          _photo = null;
          _repeat = null;
          _split = null;
          _noteController.clear();
          _tagsController.clear();
        });
        _amountFocus.requestFocus();
      }
    } else if (mounted) {
      Navigator.of(context).pop();
    }
    if (debtsAdded > 0) {
      messenger.showSnackBar(SnackBar(content: Text(l.splitSaved(debtsAdded))));
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

  /// Bottom sheet with every category of this type (searchable), and a
  /// way to manage them.
  Future<void> _pickCategory(List<String> names) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CategorySheet(
        state: widget.state,
        type: _type,
        names: names,
        selected: _category,
      ),
    );
    if (!mounted || picked == null) return;
    if (picked == _CategorySheet.manage) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            CategoriesScreen(state: widget.state, initialType: _type),
      ));
      if (mounted) setState(() {});
      return;
    }
    setState(() => _category = picked);
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
    final canSplit = !_isEditing && !isIncome;

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
              tooltip: l.duplicate,
              icon: const Icon(Icons.copy_outlined),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => EntryFormScreen(
                      state: widget.state, template: widget.entry),
                ),
              ),
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
                      _category = _defaultCategory();
                      // Only expenses are split.
                      if (_type == EntryType.income) _split = null;
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
                  // One field like Note and Tags; tapping it opens the list.
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _pickCategory(categoryNames),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: l.category,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(9),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: widget.state.colorFor(_category, _type),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                                widget.state.iconFor(_category, _type),
                                size: 17,
                                color: Colors.white),
                          ),
                        ),
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        categoryLabel(l, _category),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l.quickCategories, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  _QuickCategories(
                    state: widget.state,
                    type: _type,
                    selected: _category,
                    onPick: (c) => setState(() => _category = c),
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
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 48)),
                          icon: const Icon(Icons.schedule, size: 18),
                          label: Text(_minutes == null
                              ? l.entryTime
                              : MaterialLocalizations.of(context)
                                  .formatTimeOfDay(
                                  TimeOfDay(
                                      hour: _minutes! ~/ 60,
                                      minute: _minutes! % 60),
                                  alwaysUse24HourFormat: MediaQuery.of(context)
                                      .alwaysUse24HourFormat,
                                )),
                          onPressed: _pickTime,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
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
                      if (canSplit && _split == null) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48)),
                            icon: const Icon(Icons.call_split, size: 18),
                            label: Text(l.splitBill),
                            onPressed: _openSplit,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (canSplit && _split != null) ...[
                    const SizedBox(height: 10),
                    _SplitCard(
                      state: widget.state,
                      plan: _split!,
                      totalMinor:
                          widget.state.parseMinor(_amountController.text),
                      unit: _splitUnit,
                      onEdit: _openSplit,
                      onRemove: () => setState(() => _split = null),
                    ),
                  ],
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
                  // A split bill is saved once, never repeated.
                  if (!_isEditing && _activeSplit == null) ...[
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
                  const SizedBox(height: 14),
                  const _PrivacyNote(),
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

/// The searchable list of categories for the entry form.
class _CategorySheet extends StatefulWidget {
  const _CategorySheet({
    required this.state,
    required this.type,
    required this.names,
    required this.selected,
  });

  /// Returned instead of a name when "Manage" is tapped.
  static const String manage = '\u0000manage';

  final AppState state;
  final EntryType type;
  final List<String> names;
  final String selected;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final n in widget.names)
        if (q.isEmpty ||
            categoryLabel(l, n).toLowerCase().contains(q) ||
            n.toLowerCase().contains(q))
          n,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (ctx, scroll) => Column(
        children: [
          if (widget.names.length > 6)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: l.search,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          Expanded(
            child: ListView(
              controller: scroll,
              children: [
                for (final n in shown)
                  ListTile(
                    leading: CircleAvatar(
                      radius: 17,
                      backgroundColor: widget.state.colorFor(n, widget.type),
                      child: Icon(widget.state.iconFor(n, widget.type),
                          size: 18, color: Colors.white),
                    ),
                    title: Text(categoryLabel(l, n)),
                    selected: n == widget.selected,
                    trailing:
                        n == widget.selected ? const Icon(Icons.check) : null,
                    onTap: () => Navigator.pop(context, n),
                  ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.tune, color: theme.colorScheme.primary),
                  title: Text(l.manage,
                      style: TextStyle(color: theme.colorScheme.primary)),
                  onTap: () => Navigator.pop(context, _CategorySheet.manage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The categories used most, as big buttons: one tap picks one.
class _QuickCategories extends StatelessWidget {
  const _QuickCategories({
    required this.state,
    required this.type,
    required this.selected,
    required this.onPick,
  });

  final AppState state;
  final EntryType type;
  final String selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final names = state.topCategories(type);
    return LayoutBuilder(builder: (context, box) {
      // Three per row on phones, more on wide windows.
      final perRow = (box.maxWidth / 110).floor().clamp(3, 6).toInt();
      final double width = (box.maxWidth - (perRow - 1) * 8) / perRow;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final name in names)
            SizedBox(
              width: width,
              child: _QuickCategory(
                label: categoryLabel(l, name),
                icon: state.iconFor(name, type),
                color: state.colorFor(name, type),
                selected: name == selected,
                textStyle: theme.textTheme.bodySmall,
                onTap: () => onPick(name),
              ),
            ),
        ],
      );
    });
  }
}

class _QuickCategory extends StatelessWidget {
  const _QuickCategory({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.textStyle,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              AnimatedScale(
                scale: selected ? 1.08 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: selected ? 1 : 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: selected ? color : Colors.transparent,
                        width: 2),
                  ),
                  child: Icon(icon,
                      size: 22,
                      color: selected ? Colors.white : color),
                ),
              ),
              const SizedBox(height: 4),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// The chosen split in the entry form: who shares the bill and what that
/// means. Tap to change it, x to remove it.
class _SplitCard extends StatelessWidget {
  const _SplitCard({
    required this.state,
    required this.plan,
    required this.totalMinor,
    required this.unit,
    required this.onEdit,
    required this.onRemove,
  });

  final AppState state;
  final SplitPlan plan;

  /// The amount typed in the form (null when empty or not valid).
  final int? totalMinor;
  final int unit;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final total = totalMinor;
    final shares =
        total == null || total <= 0 ? null : plan.sharesFor(total, unit: unit);
    final payer = plan.paidBy;
    final String detail;
    if (total == null || total <= 0) {
      detail = l.enterAmountAboveZero;
    } else if (shares == null) {
      detail = l.splitSharesWrong;
    } else {
      final owe = payer == null
          ? l.othersOweYou(state.formatMoney(SplitPlan.othersTotal(shares)))
          : l.youOwePerson(payer, state.formatMoney(shares[0]));
      detail = '${l.yourShare(state.formatMoney(shares[0]))} · $owe';
    }
    final color = shares == null ? scheme.error : scheme.primary;
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 4, 8),
          child: Row(
            children: [
              Icon(Icons.call_split, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.splitWithNames(plan.people.join(', ')),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: shares == null ? scheme.error : null),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.removeSplit,
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Your data is stored only on your device."
class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(context.l10n.privacyNote,
                style: TextStyle(color: scheme.primary, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
