import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/coach/domain/entities/coach_entities.dart';
import '../../features/coach/presentation/pages/coach_shell.dart';
import '../../features/coach/presentation/pages/session_history_page.dart';
import '../../features/coach/presentation/pages/session_page.dart';
import '../../features/parent/presentation/pages/link_child_page.dart';
import '../../features/parent/presentation/pages/parent_shell.dart';
import '../constants/user_role.dart';

/// Router aplikasi. Satu codebase, dua mode.
///
/// Setelah login, `redirect` mengarahkan ke root berbeda sesuai [UserRole]:
///  - PEMBINA  -> /coach
///  - ORANGTUA -> /parent
/// Jika belum ada sesi -> /login.
final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(authSessionProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: _AuthChangeNotifier(ref),
    redirect: (context, state) {
      final s = session;
      final loc = state.matchedLocation;
      final atPublic = loc == '/login' || loc == '/register';

      if (s == null) return atPublic ? null : '/login';

      // Sudah login: pastikan berada di area sesuai role.
      final home = switch (s.role) {
        UserRole.pembina => '/coach',
        UserRole.orangtua => '/parent',
      };
      final inWrongArea = s.role == UserRole.pembina
          ? loc.startsWith('/parent')
          : loc.startsWith('/coach');

      if (atPublic || inWrongArea) return home;
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterPage()),

      // --- Mode Pembina ---
      GoRoute(
        path: '/coach',
        builder: (_, __) => const CoachShell(),
        routes: [
          GoRoute(
            path: 'history',
            builder: (_, __) => const SessionHistoryPage(),
          ),
          GoRoute(
            path: 'session/:id',
            builder: (_, state) => SessionPage(
              extracurricularId: state.pathParameters['id']!,
              session: state.extra is TodaySession ? state.extra as TodaySession : null,
            ),
          ),
        ],
      ),

      // --- Mode Orang Tua ---
      GoRoute(
        path: '/parent',
        builder: (_, __) => const ParentShell(),
        routes: [
          GoRoute(path: 'link-child', builder: (_, __) => const LinkChildPage()),
        ],
      ),
    ],
  );
});

/// Menjembatani perubahan Riverpod -> Listenable yang dipahami go_router.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier(Ref ref) {
    ref.listen(authSessionProvider, (_, __) => notifyListeners());
  }
}
