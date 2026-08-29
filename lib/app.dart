import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/providers/auth_providers.dart';

class EskulApp extends ConsumerWidget {
  const EskulApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restore = ref.watch(sessionRestoreProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Ekskul SD',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) {
        // Tahan UI dengan splash sampai upaya restore sesi selesai.
        return restore.isLoading
            ? const _Splash()
            : (child ?? const SizedBox.shrink());
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
