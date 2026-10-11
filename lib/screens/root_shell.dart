import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../android_extras.dart';
import '../app_state.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../theme.dart';
import 'budgets_screen.dart';
import 'categories_screen.dart';
import 'debts_screen.dart';
import 'entry_form_screen.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// Windows at least this wide get the sidebar layout (desktop, tablets).
const double kWideLayoutWidth = 900;

/// From this width the Home screen also shows the quick add panel.
const double kQuickAddPanelWidth = 1200;

/// Pages of the app. Phones show the first three and Settings in the
/// bottom bar; wide windows show all of them in the sidebar.
enum AppPage { home, insights, budgets, goals, lendBorrow, categories, settings }

/// The main screen: bottom bar on phones, sidebar on wide windows.
class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.state});

  final AppState state;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  AppPage _page = AppPage.home;
  late final AppLifecycleListener _lifecycle;
  StreamSubscription<Uri?>? _widgetSub;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    // Coming back to the app on a new day adds due recurring entries.
    _lifecycle = AppLifecycleListener(onResume: () => state.runRecurring());
    state.addListener(_syncWidget);
    _syncWidget();
    _widgetSub = AndroidExtras.listenWidgetAdd(_add);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Again on language change, so the shortcut names follow it.
    AndroidExtras.initShortcuts(context.l10n, _addType);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    state.removeListener(_syncWidget);
    _widgetSub?.cancel();
    super.dispose();
  }

  void _syncWidget() => AndroidExtras.updateWidget(state);

  void _addType(EntryType type) {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EntryFormScreen(state: state, initialType: type),
    ));
  }

  /// Used by Home: 1 = Insights, 2 = Budgets.
  void _openTab(int i) => setState(() => _page = AppPage.values[i]);

  void _add() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          EntryFormScreen(state: state, initialType: EntryType.expense),
    ));
  }

  void _search() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SearchScreen(state: state),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _add,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _search,
      },
      child: Focus(
        autofocus: true,
        child: LayoutBuilder(
          builder: (context, constraints) =>
              constraints.maxWidth >= kWideLayoutWidth
                  ? _wide(context, constraints.maxWidth)
                  : _narrow(context),
        ),
      ),
    );
  }

  // ---- phones: bottom bar ----

  Widget _narrow(BuildContext context) {
    final l = context.l10n;
    const pages = [
      AppPage.home,
      AppPage.insights,
      AppPage.budgets,
      AppPage.settings,
    ];
    final index = pages.contains(_page) ? pages.indexOf(_page) : 0;
    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          HomeScreen(state: state, onOpenTab: _openTab),
          StatsScreen(state: state),
          BudgetsScreen(state: state),
          SettingsScreen(state: state),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        tooltip: l.addEntry,
        onPressed: _add,
        elevation: 4,
        backgroundColor: BrandColors.of(context).brand,
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
              label: l.navHome,
              selected: index == 0,
              onTap: () => setState(() => _page = AppPage.home),
            ),
            _NavItem(
              icon: Icons.pie_chart_outline,
              selectedIcon: Icons.pie_chart_rounded,
              label: l.navInsights,
              selected: index == 1,
              onTap: () => setState(() => _page = AppPage.insights),
            ),
            const SizedBox(width: 72),
            _NavItem(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet_rounded,
              label: l.navBudgets,
              selected: index == 2,
              onTap: () => setState(() => _page = AppPage.budgets),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: l.navSettings,
              selected: index == 3,
              onTap: () => setState(() => _page = AppPage.settings),
            ),
          ],
        ),
      ),
    );
  }

  // ---- wide windows: sidebar ----

  Widget _wide(BuildContext context, double width) {
    Widget limit(Widget child, [double max = 900]) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: max),
            child: child,
          ),
        );

    final home = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: limit(HomeScreen(state: state, onOpenTab: _openTab), 820),
        ),
        if (width >= kQuickAddPanelWidth)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
            child: SizedBox(
              width: 380,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: EntryFormScreen(state: state, embedded: true),
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sidebar(
            page: _page,
            onSelect: (p) => setState(() => _page = p),
            onAdd: _add,
          ),
          Expanded(
            child: IndexedStack(
              index: _page.index,
              children: [
                home,
                limit(StatsScreen(state: state)),
                limit(BudgetsScreen(state: state)),
                limit(GoalsScreen(state: state)),
                limit(DebtsScreen(state: state)),
                limit(CategoriesScreen(state: state)),
                limit(SettingsScreen(state: state)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.page,
    required this.onSelect,
    required this.onAdd,
  });

  final AppPage page;
  final ValueChanged<AppPage> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final brand = BrandColors.of(context);
    final items = <(AppPage, IconData, IconData, String)>[
      (AppPage.home, Icons.home_outlined, Icons.home_rounded, l.navHome),
      (
        AppPage.insights,
        Icons.pie_chart_outline,
        Icons.pie_chart_rounded,
        l.navInsights
      ),
      (
        AppPage.budgets,
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded,
        l.navBudgets
      ),
      (
        AppPage.goals,
        Icons.savings_outlined,
        Icons.savings_rounded,
        l.savingsGoals
      ),
      (
        AppPage.lendBorrow,
        Icons.handshake_outlined,
        Icons.handshake_rounded,
        l.lendAndBorrow
      ),
      (
        AppPage.categories,
        Icons.category_outlined,
        Icons.category_rounded,
        l.categories
      ),
      (
        AppPage.settings,
        Icons.settings_outlined,
        Icons.settings_rounded,
        l.navSettings
      ),
    ];

    return Container(
      width: 240,
      color: brand.brand,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/icon/logo.png',
                    width: 40, height: 40),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PocketTally',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text('by Lumio Apps',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: kAccent,
              foregroundColor: brand.brand,
              minimumSize: const Size(0, 48),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(l.newEntry),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text('Ctrl+N',
                style: TextStyle(color: brand.label, fontSize: 11)),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ListView(
              children: [
                for (final (p, icon, selectedIcon, label) in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _SidebarItem(
                      icon: p == page ? selectedIcon : icon,
                      label: label,
                      selected: p == page,
                      onTap: () => onSelect(p),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: brand.brandSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.offlineTitle,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(l.offlineBody,
                    style: TextStyle(color: brand.label, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    return Material(
      color: selected ? brand.brandSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Semantics(
          selected: selected,
          button: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon,
                      size: 20, color: selected ? kAccent : brand.label),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : brand.label,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
