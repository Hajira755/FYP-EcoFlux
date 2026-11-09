// lib/viewmodels/notification_viewmodel.dart
//
// Powers both the notification-bell badge (unread count) and the full
// Notifications screen. Listens to NotificationService.getAllNotificationsStream
// in real time, same "cancel-and-resubscribe" pattern used by the other
// viewmodels in this app (ComplaintViewModel, WorkerDashboardViewModel, etc).

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/notification_service.dart';

class NotificationViewModel extends ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  bool _isLoading = false;
  String? _listeningUserId;
  List<NotificationModel> _notifications = [];

  StreamSubscription<QuerySnapshot>? _subscription;

  bool get isLoading => _isLoading;
  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Call once when a dashboard/notifications screen loads. Safe to call
  /// repeatedly — it only resubscribes if the user actually changed.
  void listenToNotifications(String userId) {
    if (userId.isEmpty) return;
    if (_listeningUserId == userId && _subscription != null) return;

    _subscription?.cancel();
    _listeningUserId = userId;
    _isLoading = true;
    notifyListeners();

    _subscription =
        _notificationService.getAllNotificationsStream(userId).listen(
              (snapshot) {
            _notifications = snapshot.docs.map((doc) {
              return NotificationModel.fromMap(
                doc.data() as Map<String, dynamic>,
                doc.id,
              );
            }).toList();

            // Newest first — sorted client-side (see NotificationService note).
            _notifications.sort((a, b) {
              final ta = a.timestamp?.toDate() ?? DateTime(0);
              final tb = b.timestamp?.toDate() ?? DateTime(0);
              return tb.compareTo(ta);
            });

            _isLoading = false;
            notifyListeners();
          },
          onError: (e) {
            debugPrint('NotificationViewModel stream error: $e');
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> markAsRead(String notificationId) async {
    await _notificationService.markNotificationRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    if (_listeningUserId == null) return;
    await _notificationService.markAllRead(_listeningUserId!);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}