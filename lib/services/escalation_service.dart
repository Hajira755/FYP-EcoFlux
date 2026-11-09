// lib/services/escalation_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'notification_service.dart';

class EscalationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  static const String _collection = 'reports';
  static const int _escalationHours = 48;

  /// Call this when admin dashboard loads.
  /// Checks all PENDING reports older than 48 hours and marks them ESCALATED.
  /// Also fires an in-app notification to the report's citizen AND to every
  /// admin account, so escalation is actually visible to the people who
  /// need to act on it (previously this only flipped the Firestore status
  /// silently with no alert at all).
  Future<void> checkAndEscalateReports() async {
    try {
      final cutoff = DateTime.now().subtract(
        const Duration(hours: _escalationHours),
      );

      final snapshot = await _db
          .collection(_collection)
          .where('status', isEqualTo: 'PENDING')
          .get();

      final batch = _db.batch();
      int escalated = 0;

      // Keep track of which reports got escalated so we can send
      // notifications AFTER the batch commits successfully.
      final escalatedReports = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
        if (timestamp != null && timestamp.isBefore(cutoff)) {
          batch.update(doc.reference, {
            'status': 'ESCALATED',
            'escalationTime': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
          escalated++;
          escalatedReports.add({
            'reportId': doc.id,
            'userId': data['userId'] ?? '',
            'category': data['category'] ?? 'Report',
          });
        }
      }

      if (escalated > 0) {
        await batch.commit();
        debugPrint('EscalationService: $escalated reports escalated.');

        // Fire notifications for each newly-escalated report.
        for (final report in escalatedReports) {
          final reportId = report['reportId'] as String;
          final userId = report['userId'] as String;
          final category = report['category'] as String;

          // Tell the citizen their report has been escalated.
          if (userId.isNotEmpty) {
            await _notificationService.notifyCitizenStatusUpdate(
              citizenId: userId,
              reportCategory: category,
              newStatus: 'ESCALATED',
              reportId: reportId,
            );
          }

          // Tell every admin so someone follows up.
          await _notificationService.notifyAdminEscalation(
            reportCategory: category,
            reportId: reportId,
          );
        }
      }
    } catch (e) {
      debugPrint('EscalationService error: $e');
    }
  }
}