import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _notifications = [];
  int _unreadCount = 0;
  final ApiService _api = ApiService();

  List<Map<String, dynamic>> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  Future<void> loadNotifications() async {
    try {
      final response = await _api.getNotifications();
      _notifications = List<Map<String, dynamic>>.from(response.data['notifications']);
      _unreadCount = response.data['unread_count'];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markRead(int id) async {
    try {
      await _api.markNotificationRead(id);
      await loadNotifications();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.markAllNotificationsRead();
      await loadNotifications();
    } catch (_) {}
  }
}
