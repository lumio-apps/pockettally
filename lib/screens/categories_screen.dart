import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';

/// Create, rename, recolor, reorder, hide and delete categories.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({
    super.key,
    required this.state,
    this.initialType = EntryType.expense,
  });

  final AppState state;
  final EntryType initialType;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialType == EntryType.expense ? 0 : 1,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Categories'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Expense'), Tab(text: 'Income')],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('New category'),
            onPressed: () {
              final index = DefaultTabController.of(context).index;
              final type = index == 0 ? EntryType.expense : EntryType.income;
              showCategoryDialog(context, state, type: type);
            },
          ),
          body: ListenableBuilder(
            listenable: state,
            builder: (context, _) => TabBarView(
              children: [
                _CategoryList(state: state, type: EntryType.expense),
                _CategoryList(state: state, type: EntryType.income),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.state, required this.type});

  final AppState state;
  final EntryType type;

  @override
  Widget build(BuildContext context) {
    final all = state.categoriesFor(type);
    // "Other" is always last and cannot be moved or hidden.
    final movable = all.where((c) => !c.isOther).toList();
    final others = all.where((c) => c.isOther).toList();

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      buildDefaultDragHandles: false,
      header: const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          'Drag to change the order. Hidden categories are not shown '
          'when adding an entry.',
          style: TextStyle(fontSize: 12),
        ),
      ),
      footer: Column(
        children: [for (final c in others) _tile(context, c, null)],
      ),
      itemCount: movable.length,
      // newIndex already accounts for the removed item.
      onReorderItem: (oldIndex, newIndex) {
        final list = [...movable];
        list.insert(newIndex, list.removeAt(oldIndex));
        state.reorderCategories(list);
      },
      itemBuilder: (context, i) => _tile(context, movable[i], i),
    );
  }

  Widget _tile(BuildContext context, EntryCategory c, int? index) {
    final count = state.entryCountFor(c);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return ListTile(
      key: ValueKey(c.id ?? c.name),
      leading: Opacity(
        opacity: c.hidden ? 0.4 : 1,
        child: CircleAvatar(backgroundColor: c.color, radius: 14),
      ),
      title: Text(
        c.name,
        style: c.hidden ? TextStyle(color: muted) : null,
      ),
      subtitle: Text([
        if (c.hidden) 'Hidden',
        count == 1 ? '1 entry' : '$count entries',
        if (c.hasBudget) 'Limit ${state.formatMoney(c.budgetMinor!)}',
      ].join(' · ')),
      onTap: () => showCategoryDialog(context, state, type: type, existing: c),
      trailing: index == null
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: c.hidden ? 'Show' : 'Hide',
                  icon: Icon(c.hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                  onPressed: () => state.setCategoryHidden(c, !c.hidden),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.drag_handle, semanticLabel: 'Drag'),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Dialog to add a new category, or edit [existing].
Future<void> showCategoryDialog(
  BuildContext context,
  AppState state, {
  required EntryType type,
  EntryCategory? existing,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CategoryDialog(state: state, type: type, existing: existing),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.state, required this.type, this.existing});

  final AppState state;
  final EntryType type;
  final EntryCategory? existing;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name;
  late final TextEditingController _budget;
  late int _color;
  String? _error;
  String? _budgetError;

  bool get _isExpense => widget.type == EntryType.expense;

  bool get _isEditing => widget.existing != null;
  bool get _isOther => widget.existing?.isOther ?? false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    final budget = widget.existing?.budgetMinor;
    _budget = TextEditingController(
        text: budget != null && budget > 0
            ? widget.state.amountInput(budget)
            : '');
    _color = widget.existing?.colorValue ??
        kCategoryPalette[widget.state.categories.length % kCategoryPalette.length];
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter a name');
      return;
    }
    if (widget.state.categoryNameTaken(name, widget.type,
        exceptId: widget.existing?.id)) {
      setState(() => _error = 'This name already exists');
      return;
    }
    int? budgetMinor;
    if (_isExpense && _budget.text.trim().isNotEmpty) {
      final v = widget.state.parseMinor(_budget.text);
      if (v == null || v <= 0) {
        setState(() => _budgetError = 'Enter an amount greater than 0');
        return;
      }
      budgetMinor = v;
    }
    // Editing keeps the category's place in the order and hidden state.
    final changed = widget.existing?.copyWith(
          name: name,
          colorValue: _color,
          budgetMinor: () => budgetMinor,
        ) ??
        EntryCategory(
          name: name,
          type: widget.type,
          colorValue: _color,
          budgetMinor: budgetMinor,
        );
    if (_isEditing) {
      await widget.state.updateCategory(widget.existing!, changed);
    } else {
      await widget.state.addCategory(changed);
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final c = widget.existing!;
    final count = widget.state.entryCountFor(c);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${c.name}"?'),
        content: Text(count == 0
            ? 'This category has no entries.'
            : '$count ${count == 1 ? 'entry' : 'entries'} will be moved to "$kOtherCategory".'),
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
    if (ok != true) return;
    await widget.state.deleteCategory(c);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.type == EntryType.expense ? 'expense' : 'income';
    return AlertDialog(
      title: Text(_isEditing ? 'Edit category' : 'New $typeLabel category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: !_isEditing,
              // "Other" keeps its name; only its color can change.
              enabled: !_isOther,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 16),
            const Text('Color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in kCategoryPalette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(c),
                      child: c == _color
                          ? const Icon(Icons.check, size: 18, color: Colors.white)
                          : null,
                    ),
                  ),
              ],
            ),
            if (_isExpense) ...[
              const SizedBox(height: 20),
              TextField(
                controller: _budget,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: 'Monthly limit (optional)',
                  prefixText: '${widget.state.currency.symbol} ',
                  helperText: 'Leave empty for no limit',
                  errorText: _budgetError,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) {
                  if (_budgetError != null) setState(() => _budgetError = null);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_isEditing && !_isOther)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}