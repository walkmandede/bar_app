// core/app_router.dart
import 'package:bar_app/core/widgets.dart';
import 'package:bar_app/features/reports/reports_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/login_page.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/inventory/history_page.dart';
import '../features/inventory/order_form_page.dart';
import '../features/items/item_detail_page.dart';
import '../features/items/item_form_page.dart';
import '../features/items/items_page.dart';
import '../models/app_user.dart';
import '../models/inventory_entry.dart';
import '../providers/providers.dart';

enum TransitionType {
  none,
  fade,
  slide,
  scale,
  fadeSlide,
}

CustomTransitionPage<void> _buildTransitionPage({
  required GoRouterState state,
  required Widget child,
  TransitionType transition = TransitionType.none,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      switch (transition) {
        case TransitionType.none:
          return child;

        case TransitionType.fade:
          return FadeTransition(
            opacity: animation,
            child: child,
          );

        case TransitionType.slide:
          return SlideTransition(
            position: animation.drive(
              Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).chain(
                CurveTween(curve: Curves.easeInOut),
              ),
            ),
            child: child,
          );

        case TransitionType.scale:
          return ScaleTransition(
            scale: animation.drive(
              Tween<double>(
                begin: 0.9,
                end: 1,
              ).chain(
                CurveTween(curve: Curves.easeOut),
              ),
            ),
            child: child,
          );

        case TransitionType.fadeSlide:
          final slideAnimation = animation.drive(
            Tween<Offset>(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).chain(
              CurveTween(curve: Curves.easeOut),
            ),
          );

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
      }
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  // Refresh redirects when authentication state changes.
  final refresh = ValueNotifier<int>(0);

  ref.listen<AppUser?>(
    authProvider,
    (_, __) => refresh.value++,
  );

  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loggedIn = ref.read(authProvider) != null;
      final atLogin = state.matchedLocation == '/login';

      if (!loggedIn) {
        return atLogin ? null : '/login';
      }

      if (atLogin) {
        return '/';
      }

      return null;
    },
    routes: [
      // Authentication
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const LoginPage(),
          transition: TransitionType.fade,
        ),
      ),

      // Home. No sidebar or bottom bar. Everything opens from the action tiles.
      GoRoute(
        path: '/',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const DashboardPage(),
          transition: TransitionType.fade,
        ),
      ),

      // Screens opened from the dashboard actions (with a back arrow)
      GoRoute(
        path: '/items',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const SubPage(child: ItemsPage()),
          transition: TransitionType.slide,
        ),
      ),
      GoRoute(
        path: '/history',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const SubPage(child: HistoryPage()),
          transition: TransitionType.slide,
        ),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const SubPage(child: ReportsPage()),
          transition: TransitionType.slide,
        ),
      ),

      // Item screens
      GoRoute(
        path: '/items/new',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: const ItemFormPage(),
          transition: TransitionType.slide,
        ),
      ),
      GoRoute(
        path: '/items/:id',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: ItemDetailPage(
            itemId: state.pathParameters['id']!,
          ),
          transition: TransitionType.slide,
        ),
      ),
      GoRoute(
        path: '/items/:id/edit',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: ItemFormPage(
            itemId: state.pathParameters['id'],
          ),
          transition: TransitionType.slide,
        ),
      ),

      // Supply, sale and manual orders
      GoRoute(
        path: '/orders/:type',
        pageBuilder: (context, state) => _buildTransitionPage(
          state: state,
          child: OrderFormPage(
            type: EntryType.values.asNameMap()[state.pathParameters['type']] ?? EntryType.supply,
            presetItemId: state.uri.queryParameters['item'],
          ),
          transition: TransitionType.slide,
        ),
      ),
    ],
  );
});
