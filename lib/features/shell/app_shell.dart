// features/shell/app_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_env.dart';
import '../../core/app_svgs.dart';
import '../../core/app_theme.dart';
import '../../core/responsive.dart';
import '../../core/widgets.dart';
import '../../providers/providers.dart';

typedef _Tab = ({String path, String label, String icon});

/// Sidebar on wide screens, bottom navigation on phones and tablets.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const List<_Tab> _tabs = [
    (path: '/', label: 'Dashboard', icon: AppSvgs.homeIcon),
    (path: '/items', label: 'Items', icon: AppSvgs.itemsIcon),
    (path: '/history', label: 'History', icon: AppSvgs.historyIcon),
  ];

  int _indexFor(String location) {
    if (location.startsWith('/items')) return 1;
    if (location.startsWith('/history')) return 2;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.path;
    final index = _indexFor(location);
    final user = ref.watch(authProvider);
    void logout() => ref.read(authProvider.notifier).logout();

    if (Responsive.isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            _Sidebar(
              tabs: _tabs,
              selected: index,
              userName: user?.displayName ?? '',
              onLogout: logout,
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('Bar Inventory', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(width: 8),
            _EnvBadge(),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: logout,
            icon: AppIcon(AppSvgs.logoutIcon, color: AppColors.text),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: AppIcon(t.icon, color: AppColors.textSoft),
              selectedIcon: AppIcon(t.icon, color: AppColors.primary),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.tabs,
    required this.selected,
    required this.userName,
    required this.onLogout,
  });

  final List<_Tab> tabs;
  final int selected;
  final String userName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  'Bar Inventory',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 8),
                _EnvBadge(),
              ],
            ),
          ),
          const SizedBox(height: 28),
          for (var i = 0; i < tabs.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _NavTile(
                tab: tabs[i],
                selected: i == selected,
                onTap: () => context.go(tabs[i].path),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              userName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onLogout,
              icon: AppIcon(AppSvgs.logoutIcon, size: 18, color: AppColors.primary),
              label: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.tab, required this.selected, required this.onTap});

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              AppIcon(
                tab.icon,
                color: selected ? AppColors.primary : AppColors.textSoft,
              ),
              const SizedBox(width: 12),
              Text(
                tab.label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? AppColors.text : AppColors.textSoft,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small label shown only outside prod.
class _EnvBadge extends StatelessWidget {
  const _EnvBadge();

  @override
  Widget build(BuildContext context) {
    if (AppEnv.isProd) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        AppEnv.envName.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
