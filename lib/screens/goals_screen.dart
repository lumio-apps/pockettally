import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../widgets/amount_dialog.dart';
import '../widgets/entry_tile.dart' show kExpenseColor;
import '../widgets/neo.dart';

/// Savings goals like "New phone: 20,000" and how far along they are.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.savingsGoals)),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(l.newGoal),
        onPressed: () => showGoalDialog(context, state),
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final goals = state.goals;
          if (goals.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  l.noGoalsYet,
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
                child: Text(l.savedInAllGoals(state.formatMoney(total)),
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
    final l = context.l10n;
    final left = goal.targetMinor - goal.savedMinor;
    return NeoCard(
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
                  Chip(
                    avatar: const Icon(Icons.emoji_events_outlined, size: 16),
                    label: Text(l.reached),
                  ),
                PopupMenuButton<String>(
                  tooltip: l.more,
                  onSelected: (v) => _onMenu(context, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit', child: Text(l.edit)),
                    PopupMenuItem(value: 'delete', child: Text(l.delete)),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.amountOfTotal(state.formatMoney(goal.savedMinor),
                              state.formatMoney(goal.targetMinor)),
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
                        ? l.goalReached
                        : l.amountToGo(state.formatMoney(left)),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          icon: const Icon(Icons.add),
                          label: Text(l.addMoney),
                          onPressed: () => _addMoney(context),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 52)),
                          icon: const Icon(Icons.remove),
                          label: Text(l.takeOut),
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
    final v = await askAmount(context, state,
        title: context.l10n.addToGoal(goal.name));
    if (v != null) {
      await state.saveGoal(goal.copyWith(savedMinor: goal.savedMinor + v));
    }
  }

  Future<void> _takeOut(BuildContext context) async {
    final v = await askAmount(
      context,
      state,
      title: context.l10n.takeOutOfGoal(goal.name),
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
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteNamedQuestion(goal.name)),
        content: Text(l.goalDeleteNote),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.cancel)),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kExpenseColor),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.delete)),
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
        text: g == null ? '' : widget.state.amountInput(g.targetMinor));
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
    final l = context.l10n;
    final name = _name.text.trim();
    final target = widget.state.parseMinor(_target.text) ?? 0;
    setState(() {
      _nameError = name.isEmpty ? l.enterName : null;
      _targetError = target <= 0 ? l.enterAmountAboveZero : null;
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
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.existing == null ? l.newGoal : l.editGoal),
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
                labelText: l.savingFor,
                hintText: l.savingForHint,
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
                labelText: l.targetAmount,
                prefixText: '${widget.state.currency.symbol} ',
                errorText: _targetError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(l.color),
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
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
