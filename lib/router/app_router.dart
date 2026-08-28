import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/about_page.dart';
import '../features/archive/archive_page.dart';
import '../features/backup/backup_page.dart';
import '../features/categories/categories_page.dart';
import '../features/consume/consume_page.dart';
import '../features/editor/editor_page.dart';
import '../features/expiring/expiring_page.dart';
import '../features/home/home_page.dart';
import '../features/item_detail/item_detail_page.dart';
import '../features/library/library_page.dart';
import '../features/locations/locations_page.dart';
import '../features/mine/mine_page.dart';
import '../features/onboarding/onboarding_page.dart';
import '../providers/settings_provider.dart';
import '../widgets/shell_scaffold.dart';

/// 页面转场：前进导航 slide_from_right 250ms easeOutCubic（design-system animation）。
CustomTransitionPage<T> _slidePage<T>(Widget child, GoRouterState state) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondary, child) {
      final curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
        child: child,
      );
    },
  );
}

GoRouter buildRouter(Ref ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final done = ref.read(settingsProvider).onboardingDone;
      final here = state.uri.path;
      if (!done && here != '/onboarding') return '/onboarding';
      if (done && here == '/onboarding') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (c, s) => _slidePage(const OnboardingPage(), s),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', pageBuilder: (c, s) => _slidePage(const HomePage(), s)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/library', pageBuilder: (c, s) => _slidePage(const LibraryPage(), s)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/consume', pageBuilder: (c, s) => _slidePage(const ConsumePage(), s)),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/mine', pageBuilder: (c, s) => _slidePage(const MinePage(), s)),
          ]),
        ],
      ),
      GoRoute(
        path: '/editor',
        pageBuilder: (c, s) => _slidePage(const EditorPage(), s),
      ),
      GoRoute(
        path: '/editor/:itemId',
        pageBuilder: (c, s) {
          final itemId = s.pathParameters['itemId']!;
          return _slidePage(EditorPage(editItemId: itemId), s);
        },
      ),
      GoRoute(
        path: '/item/:id',
        pageBuilder: (c, s) =>
            _slidePage(ItemDetailPage(itemId: s.pathParameters['id']!), s),
      ),
      GoRoute(path: '/categories', pageBuilder: (c, s) => _slidePage(const CategoriesPage(), s)),
      GoRoute(path: '/locations', pageBuilder: (c, s) => _slidePage(const LocationsPage(), s)),
      GoRoute(path: '/expiring', pageBuilder: (c, s) => _slidePage(const ExpiringPage(), s)),
      GoRoute(path: '/archive', pageBuilder: (c, s) => _slidePage(const ArchivePage(), s)),
      GoRoute(path: '/backup', pageBuilder: (c, s) => _slidePage(const BackupPage(), s)),
      GoRoute(path: '/about', pageBuilder: (c, s) => _slidePage(const AboutPage(), s)),
    ],
  );
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) => buildRouter(ref));
