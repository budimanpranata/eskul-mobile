import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:eskul_mobile/app.dart';

void main() {
  testWidgets('Aplikasi menampilkan layar login saat belum ada sesi', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EskulApp()));
    await tester.pumpAndSettle();

    expect(find.text('Masuk sebagai Pembina'), findsOneWidget);
    expect(find.text('Masuk sebagai Orang Tua'), findsOneWidget);
  });
}
