// core/app_router.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/inventory/history_page.dart';
import '../features/inventory/order_form_page.dart';
import '../features/items/item_detail_page.dart';
import '../features/items/item_form_page.dart';
import '../features/items/items_page.dart';
import '../features/shell/app_shell.dart';
import '../models/app_user.dart';
import '../models/inventory_entry.dart';
import '../providers/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Tells the router to re-check redirects when login state changes
  final refresh = ValueNotifier<int>(0);
  ref.listen<AppUser?>(authProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider) != null;
      final atLogin = state.matchedLocation == '/login';
      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),

      // Pages with sidebar / bottom navigation
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const DashboardPage()),
          GoRoute(path: '/items', builder: (_, __) => const ItemsPage()),
          GoRoute(path: '/history', builder: (_, __) => const HistoryPage()),
        ],
      ),

      // Full pages (opened on top)
      GoRoute(path: '/items/new', builder: (_, __) => const ItemFormPage()),
      GoRoute(
        path: '/items/:id',
        builder: (_, s) => ItemDetailPage(itemId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/items/:id/edit',
        builder: (_, s) => ItemFormPage(itemId: s.pathParameters['id']),
      ),
      GoRoute(
        path: '/orders/:type',
        builder: (_, s) => OrderFormPage(
          type: EntryType.values.asNameMap()[s.pathParameters['type']] ?? EntryType.supply,
          presetItemId: s.uri.queryParameters['item'],
        ),
      ),
    ],
  );
});
