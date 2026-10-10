import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils/amount_parser.dart';
import '../widgets/amount_dialog.dart';
import '../widgets/entry_tile.dart' show kExpenseColor;

/// Savings goals like "New phone: 20,000" and how far along they are.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New goal'),
        onPressed: () => showGoalDialog(context, state),
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final goals = state.goals;
          if (goals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No goals yet.\nSave towards something, like a new phone or a trip.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final total = goals.fold<int>(0, (s, g) => s + g.savedMinor);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text('Saved in all goals: ${state.formatMoney(total)}',
                    style: Theme.of(context).textTheme.labelLarge),
              ),
              for (final g in goals) ...[
                _GoalCard(state: state, goal: g),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.state, required this.goal});

  final AppState state;
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final left = goal.targetMinor - goal.savedMinor;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                      color: goal.color, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(goal.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                ),
                if (goal.isReached)
                  const Chip(
                    avatar: Icon(Icons.emoji_events_outlined, size: 16),
                    label: Text('Reached'),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'More',
                  onSelected: (v) => _onMenu(context, v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${state.formatMoney(goal.savedMinor)} of ${state.formatMoney(goal.targetMinor)}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text('${(goal.progress * 100).round()}%',
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: goal.progress,
                      minHeight: 10,
                      color: goal.color,
                      backgroundColor: goal.color.withValues(alpha: 0.18),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    goal.isReached
                        ? 'Goal reached. Well done!'
                        : '${state.formatMoney(left)} to go',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add money'),
                          onPressed: () => _addMoney(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52)),
                          icon: const Icon(Icons.remove),
                          label: const Text('Take out'),
                          onPressed: goal.savedMinor > 0
                              ? () => _takeOut(context)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addMoney(BuildContext context) async {
    final v = await askAmount(context, state, title: 'Add to ${goal.name}');
    if (v != null) {
      await state.saveGoal(goal.copyWith(savedMinor: goal.savedMinor + v));
    }
  }

  Future<void> _takeOut(BuildContext context) async {
    final v = await askAmount(
      context,
      state,
      title: 'Take out of ${goal.name}',
      maxMinor: goal.savedMinor,
    );
    if (v != null) {
      await state.saveGoal(goal.copyWith(savedMinor: goal.savedMinor - v));
    }
  }

  Future<void> _onMenu(BuildContext context, String action) async {
    if (action == 'edit') {
      await showGoalDialog(context, state, existing: goal);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${goal.name}"?'),
        content: const Text('The saved amount in this goal is removed too.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kExpenseColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await state.deleteGoal(goal);
  }
}

/// Create a goal, or edit [existing].
Future<void> showGoalDialog(BuildContext context, AppState state,
    {SavingsGoal? existing}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _GoalDialog(state: state, existing: existing),
  );
}

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({required this.state, this.existing});

  final AppState state;
  final SavingsGoal? existing;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late int _color;
  String? _nameError;
  String? _targetError;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _name = TextEditingController(text: g?.name ?? '');
    _target = TextEditingController(
        text: g == null ? '' : (g.targetMinor / 100).toStringAsFixed(2));
    _color = g?.colorValue ??
        kCategoryPalette[(widget.state.goals.length * 3 + 4) %
            kCategoryPalette.length];
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final v = evaluateAmount(_target.text);
    final target = v == null ? 0 : (v * 100).round();
    setState(() {
      _nameError = name.isEmpty ? 'Enter a name' : null;
      _targetError = target <= 0 ? 'Enter an amount greater than 0' : null;
    });
    if (_nameError != null || _targetError != null) return;
    final old = widget.existing;
    await widget.state.saveGoal(SavingsGoal(
      id: old?.id,
      name: name,
      targetMinor: target,
      savedMinor: old?.savedMinor ?? 0,
      colorValue: _color,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New goal' : 'Edit goal'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'What are you saving for?',
                hintText: 'New phone',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _target,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Target amount',
                prefixText: '${widget.state.currency.symbol} ',
                errorText: _targetError,
                border: const OutlineInputBorder(),
              ),
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
                          ? const Icon(Icons.check,
                              size: 18, color: Colors.white)
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
