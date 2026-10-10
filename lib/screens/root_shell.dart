import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'budgets_screen.dart';
import 'entry_form_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// The main screen: four tabs with an Add button in the middle.
class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.state});

  final AppState state;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  void _openTab(int i) => setState(() => _index = i);

  void _add() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          EntryFormScreen(state: widget.state, initialType: EntryType.expense),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          HomeScreen(state: state, onOpenTab: _openTab),
          StatsScreen(state: state),
          BudgetsScreen(state: state),
          SettingsScreen(state: state),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add entry',
        onPressed: _add,
        elevation: 4,
        backgroundColor: kBrand,
        foregroundColor: kAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 72,
        padding: EdgeInsets.zero,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
              selected: _index == 0,
              onTap: () => _openTab(0),
            ),
            _NavItem(
              icon: Icons.pie_chart_outline,
              selectedIcon: Icons.pie_chart_rounded,
              label: 'Insights',
              selected: _index == 1,
              onTap: () => _openTab(1),
            ),
            const SizedBox(width: 72),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet_rounded,
              label: 'Budgets',
              selected: _index == 2,
              onTap: () => _openTab(2),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: 'Settings',
              selected: _index == 3,
              onTap: () => _openTab(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Semantics(
          selected: selected,
          button: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
