import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/presentation/providers/auth_providers.dart';

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.isRead,
    required this.sentAt,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final bool isRead;
  final String sentAt;

  factory NotificationItem.fromJson(Map<String, dynamic> j) => NotificationItem(
        id: j['id'] as String,
        type: j['type'] as String,
        title: j['title'] as String,
        body: j['body'] as String?,
        isRead: j['isRead'] as bool? ?? j['is_read'] as bool? ?? false,
        sentAt: (j['sentAt'] ?? j['sent_at']) as String,
      );
}

class NotificationsPageData {
  const NotificationsPageData({required this.items, required this.unread});
  final List<NotificationItem> items;
  final int unread;
}

class NotificationsRepository {
  NotificationsRepository(this._dio);
  final Dio _dio;

  Future<NotificationsPageData> list({int page = 1}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/notifications',
      queryParameters: {'page': page, 'pageSize': 30},
    );
    final data = r.data!;
    final items = (data['data'] as List)
        .map((e) => NotificationItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final unread = (data['meta'] as Map)['unread'] as int? ?? 0;
    return NotificationsPageData(items: items, unread: unread);
  }

  Future<int> unreadCount() async {
    final r = await _dio.get<Map<String, dynamic>>('/notifications/unread-count');
    return r.data!['unread'] as int;
  }

  Future<void> markRead(List<String> ids) =>
      _dio.post<dynamic>('/notifications/read', data: {'ids': ids});

  Future<void> markAllRead() => _dio.post<dynamic>('/notifications/read-all');
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(dioProvider));
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) {
  // hanya relevan saat ada sesi
  if (ref.watch(authSessionProvider) == null) return Future.value(0);
  return ref.watch(notificationsRepositoryProvider).unreadCount();
});

final notificationsListProvider =
    FutureProvider.autoDispose<NotificationsPageData>((ref) {
  return ref.watch(notificationsRepositoryProvider).list();
});
