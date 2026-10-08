import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

/// Create, rename, recolor and delete categories.
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
    final list = state.categoriesFor(type);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final c = list[i];
        final count = state.entryCountFor(c);
        return ListTile(
          leading: CircleAvatar(backgroundColor: c.color, radius: 14),
          title: Text(c.name),
          subtitle: Text(count == 1 ? '1 entry' : '$count entries'),
          onTap: () => showCategoryDialog(context, state, type: type, existing: c),
          trailing: c.isOther
              ? null
              : IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, c, count),
                ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, EntryCategory c, int count) async {
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
    if (ok == true) await state.deleteCategory(c);
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
  late int _color;
  String? _error;

  bool get _isEditing => widget.existing != null;
  bool get _isOther => widget.existing?.isOther ?? false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.colorValue ??
        kCategoryPalette[widget.state.categories.length % kCategoryPalette.length];
  }

  @override
  void dispose() {
    _name.dispose();
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
    final changed = EntryCategory(
      id: widget.existing?.id,
      name: name,
      type: widget.type,
      colorValue: _color,
    );
    if (_isEditing) {
      await widget.state.updateCategory(widget.existing!, changed);
    } else {
      await widget.state.addCategory(changed);
    }
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
