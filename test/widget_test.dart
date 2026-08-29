import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eskul_mobile/app.dart';
import 'package:eskul_mobile/features/auth/presentation/providers/auth_providers.dart';

void main() {
  testWidgets('Tanpa sesi → menampilkan form login (email + password)', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        // secure storage tidak tersedia di test env → lewati pemulihan sesi.
        overrides: [sessionRestoreProvider.overrideWith((ref) async {})],
        child: const EskulApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Email / No. HP'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Masuk'), findsOneWidget);
  });
}
