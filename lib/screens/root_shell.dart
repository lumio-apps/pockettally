import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../android_extras.dart';
import '../app_state.dart';
import '../auto_backup.dart';
import '../l10n/l10n.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/app_logo.dart';
import '../widgets/neo.dart';
import 'app_page.dart';
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


/// The main screen: bottom bar on phones, sidebar on wide windows.
class RootShell extends StatefulWidget {
  const RootShell({super.key, required this.state});

  final AppState state;

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell>
    with SingleTickerProviderStateMixin {
  AppPage _page = AppPage.home;
  late final AppLifecycleListener _lifecycle;

  /// The menu that opens from the + button (phones).
  late final AnimationController _menu = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..addStatusListener((_) {
      if (mounted) setState(() {});
    });

  bool get _menuOpen =>
      _menu.status == AnimationStatus.forward ||
      _menu.status == AnimationStatus.completed;

  AppState get state => widget.state;

  @override
  void initState() {
    super.initState();
    // Coming back to the app on a new day adds due recurring entries.
    _lifecycle = AppLifecycleListener(onResume: () {
      state.runRecurring().catchError((_) => 0);
      // A new day may need a new reminder plan and a backup.
      state.syncReminder();
      state.syncDebtReminders();
      // A new month starts the widgets' balance again.
      state.syncWidget();
      AutoBackup.runIfDue(state).catchError((_) => false);
    });
    // "Add expense" / "Add income" from a launcher shortcut or a widget.
    AndroidExtras.listen(_onLaunchAction);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final action = await AndroidExtras.takeAction();
      if (action != null) _onLaunchAction(action);
    });
  }

  /// Opens the expense or income form for a shortcut or widget button.
  /// With the app lock on, the PIN screen stays on top until unlocked.
  void _onLaunchAction(String action) {
    if (!mounted) return;
    final EntryType type;
    switch (action) {
      case 'expense':
        type = EntryType.expense;
      case 'income':
        type = EntryType.income;
      default:
        return;
    }
    _closeMenu();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EntryFormScreen(state: state, initialType: type),
    ));
  }

  @override
  void dispose() {
    _menu.dispose();
    _lifecycle.dispose();
    super.dispose();
  }

  /// True while the sidebar layout is shown.
  bool _wideLayout = false;

  /// Used by Home. Pages without a tab on phones (Budgets, Lend & Borrow,
  /// Goals…) open as their own screen there.
  void _openTab(AppPage p) {
    if (!_wideLayout && !_phoneTabs.contains(p)) {
      _closeMenu();
      final Widget screen = switch (p) {
        AppPage.budgets => BudgetsScreen(state: state),
        AppPage.goals => GoalsScreen(state: state),
        AppPage.lendBorrow => DebtsScreen(state: state),
        AppPage.categories => CategoriesScreen(state: state),
        _ => SettingsScreen(state: state),
      };
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
      return;
    }
    _go(p);
  }

  /// The tabs of the phone layout, in bar order.
  static const _phoneTabs = [
    AppPage.home,
    AppPage.entries,
    AppPage.insights,
    AppPage.settings,
  ];

  void _add() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          EntryFormScreen(state: state, initialType: EntryType.expense),
    ));
  }

  void _toggleMenu() => _menuOpen ? _menu.reverse() : _menu.forward();

  void _closeMenu() {
    if (_menuOpen) _menu.reverse();
  }

  void _go(AppPage p) {
    _closeMenu();
    setState(() => _page = p);
  }

  /// What the + button offers, nearest to the thumb last.
  List<_AddOption> _addOptions(AppLocalizations l) => [
        _AddOption(
          icon: Icons.savings_outlined,
          label: l.savingsGoals,
          background: const Color(0xFFFFF0CC),
          foreground: const Color(0xFF8A5A00),
          screen: () => GoalsScreen(state: state),
        ),
        _AddOption(
          icon: Icons.handshake_outlined,
          label: l.lendAndBorrow,
          background: const Color(0xFFDDE6FA),
          foreground: const Color(0xFF2F4DA8),
          // Straight to the form; the Lend/Borrow tab shows the list.
          screen: () => DebtFormScreen(state: state),
        ),
        _AddOption(
          icon: Icons.add,
          label: l.income,
          background: const Color(0xFFD7F3E6),
          foreground: const Color(0xFF1B6E4C),
          screen: () =>
              EntryFormScreen(state: state, initialType: EntryType.income),
        ),
        _AddOption(
          icon: Icons.remove,
          label: l.expense,
          background: const Color(0xFFFFE3DE),
          foreground: const Color(0xFFB3261E),
          screen: () =>
              EntryFormScreen(state: state, initialType: EntryType.expense),
        ),
      ];

  void _openFromMenu(_AddOption option) {
    _menu.reverse();
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => option.screen()));
  }

  /// Wide windows: the same choices in a small animated dialog.
  Future<void> _showAddDialog() async {
    final l = context.l10n;
    final picked = await showGeneralDialog<_AddOption>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, _, __) => Center(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final o in _addOptions(l).reversed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _AddMenuButton(
                      option: o, onTap: () => Navigator.pop(ctx, o)),
                ),
            ],
          ),
        ),
      ),
      transitionBuilder: (ctx, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (picked != null && mounted) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => picked.screen()));
    }
  }

  void _search() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EntriesScreen(state: state, searchFirst: true),
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
        child: LayoutBuilder(builder: (context, constraints) {
          _wideLayout = constraints.maxWidth >= kWideLayoutWidth;
          return _wideLayout
              ? _wide(context, constraints.maxWidth)
              : _narrow(context);
        }),
      ),
    );
  }

  // ---- phones: bottom bar ----

  Widget _narrow(BuildContext context) {
    final l = context.l10n;
    const pages = _phoneTabs;
    final index = pages.contains(_page) ? pages.indexOf(_page) : 0;
    return PopScope(
      // Back closes the + menu first.
      canPop: !_menuOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeMenu();
      },
      child: Scaffold(
        body: Stack(
          children: [
            IndexedStack(
              index: index,
              children: [
                HomeScreen(state: state, onOpenTab: _openTab),
                EntriesScreen(state: state),
                StatsScreen(state: state),
                SettingsScreen(state: state),
              ],
            ),
            _AddMenu(
              animation: _menu,
              options: _addOptions(l),
              onPick: _openFromMenu,
              onClose: _closeMenu,
            ),
          ],
        ),
        bottomNavigationBar: _NeoNavBar(
          menu: _menu,
          // The + button takes the middle slot (2).
          slot: index < 2 ? index : index + 1,
          addTooltip: _menuOpen
              ? MaterialLocalizations.of(context).closeButtonTooltip
              : l.addEntry,
          onAdd: _toggleMenu,
          items: [
            _NavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: l.navHome,
              selected: index == 0,
              onTap: () => _go(AppPage.home),
            ),
            _NavItem(
              icon: Icons.receipt_long_outlined,
              selectedIcon: Icons.receipt_long,
              label: l.entries,
              selected: index == 1,
              onTap: () => _go(AppPage.entries),
            ),
            // Room for the + button in the middle.
            const SizedBox(width: 72),
            _NavItem(
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart_rounded,
              label: l.reports,
              selected: index == 2,
              onTap: () => _go(AppPage.insights),
            ),
            _NavItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: l.settings,
              selected: index == 3,
              onTap: () => _go(AppPage.settings),
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
              child: NeoCard(
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
            onAdd: _showAddDialog,
          ),
          Expanded(
            child: IndexedStack(
              index: _page.index,
              children: [
                home,
                limit(EntriesScreen(state: state)),
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
        AppPage.entries,
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        l.entries
      ),
      (
        AppPage.insights,
        Icons.pie_chart_outline,
        Icons.pie_chart_rounded,
        l.reports
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
        l.settings
      ),
    ];

    return Container(
      width: 240,
      color: brand.brand,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              AppLogo(size: 40),
              SizedBox(width: 12),
              Expanded(
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

/// The flat bottom bar of the phone layout, with the + button in the
/// middle. The selected tab has a light accent pill.
class _NeoNavBar extends StatelessWidget {
  const _NeoNavBar({
    required this.items,
    required this.slot,
    required this.menu,
    required this.addTooltip,
    required this.onAdd,
  });

  final List<Widget> items;

  /// 0 to 4: the tab (or the + slot) the pill sits under.
  final int slot;
  final Animation<double> menu;
  final String addTooltip;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final brand = BrandColors.of(context);
    final neo = NeoPalette.of(context);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 68,
              child: DecoratedBox(
                // A flat bar across the screen with a thin top line.
                decoration: BoxDecoration(
                  color: neo.base,
                  border: Border(top: BorderSide(color: neo.lo)),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 8),
                        child: Align(
                          alignment: Alignment(-1 + slot * 0.5, 0),
                          child: FractionallySizedBox(
                            widthFactor: 0.2,
                            heightFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Material(
                      type: MaterialType.transparency,
                      child: Row(children: items),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              child: Tooltip(
                message: addTooltip,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: brand.brand,
                    border: Border.all(color: neo.base, width: 4),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: onAdd,
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        // + turns into x while the menu is open.
                        child: RotationTransition(
                          turns: Tween(begin: 0.0, end: 0.125).animate(
                              CurvedAnimation(
                                  parent: menu, curve: Curves.easeOutBack)),
                          child: const Icon(Icons.add,
                              size: 30, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
        borderRadius: BorderRadius.circular(30),
        child: Semantics(
          selected: selected,
          button: true,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(selected ? selectedIcon : icon, color: color),
                const SizedBox(height: 2),
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
      ),
    );
  }
}

/// One choice of the + menu.
class _AddOption {
  const _AddOption({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.screen,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final Widget Function() screen;
}

/// A rounded button with a colored icon and a label.
class _AddMenuButton extends StatelessWidget {
  const _AddMenuButton({required this.option, required this.onTap});

  final _AddOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 250,
      child: NeoCard(
        radius: 30,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: option.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(option.icon, color: option.foreground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The menu above the + button: a dimmed background and the choices,
/// which slide up one after another.
class _AddMenu extends StatelessWidget {
  const _AddMenu({
    required this.animation,
    required this.options,
    required this.onPick,
    required this.onClose,
  });

  final Animation<double> animation;
  final List<_AddOption> options;
  final ValueChanged<_AddOption> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final v = animation.value;
        if (v == 0) return const SizedBox.shrink();
        final n = options.length;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onClose,
                // The page fades into the soft surface while the menu is open.
                child: ColoredBox(
                  color:
                      NeoPalette.of(context).page.withValues(alpha: 0.9 * v),
                ),
              ),
            ),
            Positioned(
              // Above the + button in the middle of the bar.
              left: 0,
              right: 0,
              bottom: 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < n; i++)
                    Builder(builder: (context) {
                      // The bottom choice comes first.
                      final start = (n - 1 - i) * 0.12;
                      final t = Curves.easeOutCubic.transform(
                          ((v - start) / (1 - 0.12 * (n - 1)))
                              .clamp(0.0, 1.0));
                      return Opacity(
                        opacity: t,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - t)),
                          child: Transform.scale(
                            scale: 0.9 + 0.1 * t,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: _AddMenuButton(
                                option: options[i],
                                onTap: () => onPick(options[i]),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
