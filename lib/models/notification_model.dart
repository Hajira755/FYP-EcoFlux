// lib/models/notification_model.dart
//
// Represents a single document in the top-level 'notifications' Firestore
// collection. Written by NotificationService.sendNotificationRecord() and
// read back by NotificationViewModel for the in-app Notifications screen
// and the unread-count bell badge.

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String toUserId;
  final String title;
  final String body;

  /// 'report_assigned' | 'status_update' | 'help_request' | 'escalation'
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final Timestamp? timestamp;

  NotificationModel({
    required this.notificationId,
    required this.toUserId,
    required this.title,
    required this.body,
    required this.type,
    this.data = const {},
    this.isRead = false,
    this.timestamp,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map, String id) {
    return NotificationModel(
      notificationId: id,
      toUserId: map['toUserId'] ?? '',
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? '',
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      isRead: map['isRead'] ?? false,
      timestamp: map['timestamp'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toUserId': toUserId,
      'title': title,
      'body': body,
      'type': type,
      'data': data,
      'isRead': isRead,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
    };
  }
}