import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/parent_repository.dart';
import '../../domain/entities/parent_entities.dart';

final parentRepositoryProvider = Provider<ParentRepository>((ref) {
  return ParentRepositoryImpl(ref.watch(dioProvider));
});

/// GET /parent/children (anak yang relasinya APPROVED).
final childrenProvider = FutureProvider.autoDispose<List<Child>>((ref) {
  return ref.watch(parentRepositoryProvider).children();
});

/// studentId anak yang sedang dipilih di dashboard (null = pakai anak pertama).
class SelectedChildNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String studentId) => state = studentId;
}

final selectedChildProvider =
    NotifierProvider<SelectedChildNotifier, String?>(SelectedChildNotifier.new);

final childProgressProvider =
    FutureProvider.autoDispose.family<ChildProgress, String>((ref, studentId) {
  return ref.watch(parentRepositoryProvider).childProgress(studentId);
});
