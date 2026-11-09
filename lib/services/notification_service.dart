// lib/services/notification_service.dart
//
// Setup required:
//   1. flutter pub add firebase_messaging flutter_local_notifications
//   2. Follow FlutterFire docs for AndroidManifest.xml + iOS Info.plist setup
//   3. Add google-services.json (Android) & GoogleService-Info.plist (iOS)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Handle background FCM messages (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('NotificationService [BG]: ${message.notification?.title}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db  = FirebaseFirestore.instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const _channelId   = 'ecoflux_channel';
  static const _channelName = 'EcoFlux Notifications';

  // ── Initialize ─────────────────────────────────────────────────────────────
  Future<void> initialize() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler);

    // Request permission (iOS + Android 13+)
    final settings = await _fcm.requestPermission(
      alert:        true,
      badge:        true,
      sound:        true,
      announcement: false,
      provisional:  false,
    );
    debugPrint(
        'NotificationService: permission = ${settings.authorizationStatus}');

    // Android local notification channel
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'EcoFlux waste management notifications',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Init local notifications plugin
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS:     DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(initSettings);

    // Foreground message listener
    FirebaseMessaging.onMessage.listen((message) {
      _showLocalNotification(message);
    });

    // Notification tap handler (app in background)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint(
          'NotificationService: opened from background — ${message.data}');
      // Navigate based on message.data['route'] if needed
    });

    debugPrint('NotificationService: initialized ✅');
  }

  // ── Save FCM token to Firestore ────────────────────────────────────────────
  /// Call after login. Role = 'citizen' | 'worker' | 'admin'
  Future<void> saveToken({
    required String userId,
    required String role,
  }) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) return;

      final collection = role == 'worker' ? 'workers' : 'users';
      await _db.collection(collection).doc(userId).set(
        {'fcmToken': token, 'tokenUpdatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      debugPrint('NotificationService: token saved for $userId ($role)');
    } catch (e) {
      debugPrint('NotificationService saveToken error: $e');
    }
  }

  // ── Show local notification (foreground) ───────────────────────────────────
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'EcoFlux notifications',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  // ── Send notification to a specific user/worker ────────────────────────────
  /// This stores a notification document in Firestore.
  /// Use Cloud Functions to trigger FCM from these documents, OR
  /// call your own backend endpoint that sends via FCM HTTP v1 API.
  Future<void> sendNotificationRecord({
    required String toUserId,
    required String title,
    required String body,
    required String type,     // 'report_assigned' | 'status_update' | 'help_request' | 'escalation'
    Map<String, dynamic>? data,
  }) async {
    try {
      await _db.collection('notifications').add({
        'toUserId':  toUserId,
        'title':     title,
        'body':      body,
        'type':      type,
        'data':      data ?? {},
        'isRead':    false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('NotificationService: record saved → $title');
    } catch (e) {
      debugPrint('NotificationService sendNotificationRecord error: $e');
    }
  }

  // ── Convenience helpers ────────────────────────────────────────────────────

  /// Notify worker when a report is assigned to them
  Future<void> notifyWorkerAssigned({
    required String workerId,
    required String reportCategory,
    required String reportId,
  }) async {
    await sendNotificationRecord(
      toUserId: workerId,
      title:    '📋 New Task Assigned',
      body:     'You have been assigned: $reportCategory',
      type:     'report_assigned',
      data:     {'reportId': reportId},
    );
  }

  /// Notify citizen when their report status changes
  Future<void> notifyCitizenStatusUpdate({
    required String citizenId,
    required String reportCategory,
    required String newStatus,
    required String reportId,
  }) async {
    await sendNotificationRecord(
      toUserId: citizenId,
      title:    '🔄 Report Status Updated',
      body:     '$reportCategory is now ${newStatus.replaceAll('_', ' ')}',
      type:     'status_update',
      data:     {'reportId': reportId, 'status': newStatus},
    );
  }

  /// Resolves every 'admin' user's uid from the 'users' collection.
  /// There is no single fixed adminId anywhere in this app (any number
  /// of admin accounts can exist), so escalation / help-request alerts
  /// are broadcast to ALL admins rather than one hardcoded id.
  Future<List<String>> _getAdminUserIds() async {
    try {
      final snap =
      await _db.collection('users').where('role', isEqualTo: 'admin').get();
      return snap.docs.map((d) => d.id).toList();
    } catch (e) {
      debugPrint('NotificationService _getAdminUserIds error: $e');
      return [];
    }
  }

  /// Notify ALL admins when a report is escalated (48hr rule)
  Future<void> notifyAdminEscalation({
    required String reportCategory,
    required String reportId,
  }) async {
    final adminIds = await _getAdminUserIds();
    for (final adminId in adminIds) {
      await sendNotificationRecord(
        toUserId: adminId,
        title:    '⚠ Report Escalated',
        body:     '$reportCategory has been escalated after 48 hours',
        type:     'escalation',
        data:     {'reportId': reportId},
      );
    }
  }

  /// Notify worker when a citizen leaves feedback on a report they resolved
  Future<void> notifyWorkerFeedback({
    required String workerId,
    required int rating,
    required String reportCategory,
    required String reportId,
  }) async {
    final stars = '⭐' * rating;
    await sendNotificationRecord(
      toUserId: workerId,
      title:    '💬 New Feedback Received',
      body:     '$stars — Feedback on: $reportCategory',
      type:     'feedback_received',
      data:     {'reportId': reportId, 'rating': rating},
    );
  }

  /// Notify ALL admins when a worker requests help
  Future<void> notifyAdminHelpRequest({
    required String workerName,
    required String reportId,
    required String message,
  }) async {
    final adminIds = await _getAdminUserIds();
    for (final adminId in adminIds) {
      await sendNotificationRecord(
        toUserId: adminId,
        title:    '🆘 Worker Needs Help',
        body:     '$workerName: $message',
        type:     'help_request',
        data:     {'reportId': reportId, 'workerName': workerName},
      );
    }
  }

  // ── Real-time in-app notifications stream ──────────────────────────────────
  /// Unread-only stream — used for the bell badge count.
  Stream<QuerySnapshot> getNotificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots();
  }

  /// Full history (read + unread) — used by the Notifications screen list.
  /// No .orderBy() here on purpose — sorting is done client-side in
  /// NotificationViewModel, same convention as the rest of the app, so no
  /// Firestore composite index needs to be created for this to work.
  Stream<QuerySnapshot> getAllNotificationsStream(String userId) {
    return _db
        .collection('notifications')
        .where('toUserId', isEqualTo: userId)
        .snapshots();
  }

  /// Mark ONE notification as read (tapped by the user on the list).
  Future<void> markNotificationRead(String notificationId) async {
    try {
      await _db
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e) {
      debugPrint('NotificationService markNotificationRead error: $e');
    }
  }

  /// Mark all notifications as read
  Future<void> markAllRead(String userId) async {
    try {
      final snap = await _db
          .collection('notifications')
          .where('toUserId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('NotificationService markAllRead error: $e');
    }
  }
}