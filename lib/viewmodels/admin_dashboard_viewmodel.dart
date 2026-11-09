// lib/viewmodels/admin_dashboard_viewmodel.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../models/complaint_model.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_repository.dart';
import '../services/escalation_service.dart';
import '../services/notification_service.dart';
import '../core/constants/app_constants.dart';

class AdminDashboardViewModel extends ChangeNotifier {
  final ReportRepository  _reportRepository  = GetIt.instance<ReportRepository>();
  final UserRepository    _userRepository    = GetIt.instance<UserRepository>();
  final EscalationService _escalationService = EscalationService();
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool    _isLoading    = false;
  String? _errorMessage;

  List<ComplaintModel>       _allReports = [];
  List<Map<String, dynamic>> _workers    = [];
  List<Map<String, dynamic>> _users      = [];

  // ── Getters ────────────────────────────────────────────────────────────────
  bool    get isLoading    => _isLoading;
  String? get errorMessage => _errorMessage;
  List<ComplaintModel>       get allReports => _allReports;
  List<Map<String, dynamic>> get workers    => _workers;
  List<Map<String, dynamic>> get users      => _users;

  int get pending    => _allReports.where((r) => r.status.toUpperCase() == 'PENDING').length;
  int get assigned   => _allReports.where((r) => r.status.toUpperCase() == 'ASSIGNED').length;
  int get inProgress => _allReports.where((r) => r.status.toUpperCase() == 'IN_PROGRESS').length;
  int get completed  => _allReports.where((r) => r.status.toUpperCase() == 'COMPLETED').length;
  int get escalated  => _allReports.where((r) => r.status.toUpperCase() == 'ESCALATED').length;
  int get total      => _allReports.length;

  List<ComplaintModel> get prioritizedReports {
    final list = List<ComplaintModel>.from(_allReports);
    list.sort((a, b) {
      int score(ComplaintModel r) {
        if (r.status.toUpperCase() == 'ESCALATED') return 0;
        if (r.priority.toLowerCase() == 'high')    return 1;
        if (r.priority.toLowerCase() == 'medium')  return 2;
        return 3;
      }
      final ps = score(a).compareTo(score(b));
      if (ps != 0) return ps;
      final ta = a.timestamp?.toDate() ?? DateTime(0);
      final tb = b.timestamp?.toDate() ?? DateTime(0);
      return tb.compareTo(ta);
    });
    return list;
  }

  List<Map<String, dynamic>> get weeklyReportData {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      final count = _allReports.where((r) {
        final t = r.timestamp?.toDate();
        if (t == null) return false;
        return t.year == day.year &&
            t.month == day.month &&
            t.day == day.day;
      }).length;
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return {'day': days[day.weekday - 1], 'count': count};
    });
  }

  StreamSubscription<QuerySnapshot>? _reportsSubscription;

  // ── Load ───────────────────────────────────────────────────────────────────
  Future<void> loadAdminStats() async {
    _isLoading = true;
    notifyListeners();

    await _escalationService.checkAndEscalateReports();
    await Future.wait([_loadWorkers(), _loadUsers()]);

    _reportsSubscription?.cancel();
    _reportsSubscription = _reportRepository.getAllComplaints().listen(
          (snapshot) {
        _allReports = snapshot.docs.map((doc) {
          return ComplaintModel.fromMap(
              doc.data() as Map<String, dynamic>, doc.id);
        }).toList();
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  Future<void> _loadWorkers() async {
    try {
      final snap = await _db.collection('workers').get();
      _workers = snap.docs.map((d) {
        final data = d.data();
        // ── KEY FIX ──────────────────────────────────────────────────────────
        // Resolve the worker's Firebase Auth UID from whichever field stores it.
        // Your Firestore docs use 'workerId' field for the auth UID.
        // We also check 'authUid' for docs created via the Add Worker sheet.
        // 'effectiveAuthUid' is what gets stored in assignedWorkerId on reports.
        final effectiveAuthUid =
        _resolveAuthUid(data, d.id);

        return {
          'id':              d.id,           // Firestore doc ID
          'effectiveAuthUid': effectiveAuthUid, // Firebase Auth UID — use this for assignment
          ...data,
        };
      }).toList();

      debugPrint('AdminVM: loaded ${_workers.length} workers');
      for (final w in _workers) {
        debugPrint(
          'AdminVM worker: name=${w['name']}, '
              'docId=${w['id']}, '
              'effectiveAuthUid=${w['effectiveAuthUid']}',
        );
      }
    } catch (e) {
      debugPrint('AdminVM _loadWorkers error: $e');
    }
  }

  /// Resolves the Firebase Auth UID from a worker Firestore document.
  /// Priority: workerId field → authUid field → doc ID (last resort).
  String _resolveAuthUid(Map<String, dynamic> data, String docId) {
    // 1. 'workerId' field — your current schema (screenshot confirms this)
    final workerIdField = data['workerId'] as String?;
    if (workerIdField != null && workerIdField.isNotEmpty) {
      return workerIdField;
    }
    // 2. 'authUid' field — used by the Add Worker sheet
    final authUidField = data['authUid'] as String?;
    if (authUidField != null && authUidField.isNotEmpty) {
      return authUidField;
    }
    // 3. Last resort: Firestore doc ID
    // (only works if someone created the doc with doc ID == auth UID)
    debugPrint('AdminVM WARNING: worker $docId has no workerId/authUid field. '
        'Falling back to doc ID. Assignment may not work!');
    return docId;
  }

  Future<void> _loadUsers() async {
    try {
      final snap = await _db.collection('users').get();
      _users = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    } catch (e) {
      debugPrint('AdminVM _loadUsers error: $e');
    }
  }

  // ── Assign worker ──────────────────────────────────────────────────────────
  /// [workerId] is the worker's Firebase Auth UID (effectiveAuthUid),
  /// passed directly from the UI picker after the fix in admin_dashboard_screen.
  /// This is stored in assignedWorkerId on the report, and matched against
  /// the worker's auth UID in the worker dashboard query.
  Future<bool> assignWorker({
    required String reportId,
    required String workerId,   // ← Firebase Auth UID (effectiveAuthUid)
    required String workerName,
  }) async {
    try {
      debugPrint('AdminVM: assigning report=$reportId to authUid=$workerId workerName=$workerName');
      await _reportRepository.assignWorkerToComplaint(
          reportId, workerId, workerName);

      // Notify the worker they've got a new task. Look up the report's
      // category from the already-loaded list for a friendlier message;
      // falls back to a generic label if it's not in the local cache yet.
      final report = _allReports.where((r) => r.complaintId == reportId);
      final category = report.isNotEmpty ? report.first.category : 'Report';
      await _notificationService.notifyWorkerAssigned(
        workerId: workerId,
        reportCategory: category,
        reportId: reportId,
      );

      return true;
    } catch (e) {
      _errorMessage = 'Failed to assign worker: $e';
      debugPrint('AdminVM assignWorker error: $e');
      notifyListeners();
      return false;
    }
  }

  // ── Update status ──────────────────────────────────────────────────────────
  Future<bool> updateStatus(String reportId, String status) async {
    try {
      // Look this up BEFORE the write — _allReports still holds the OLD
      // status here, which is exactly what we need to detect a genuine
      // PENDING/ASSIGNED/IN_PROGRESS -> COMPLETED transition and avoid
      // re-awarding points if an admin sets it to COMPLETED more than once.
      final report = _allReports.where((r) => r.complaintId == reportId);
      final wasAlreadyCompleted =
          report.isNotEmpty && report.first.status.toUpperCase() == 'COMPLETED';

      await _reportRepository.updateComplaintStatus(reportId, status);

      if (report.isNotEmpty) {
        final r = report.first;

        // Let the citizen know their report moved forward.
        await _notificationService.notifyCitizenStatusUpdate(
          citizenId: r.userId,
          reportCategory: r.category,
          newStatus: status,
          reportId: reportId,
        );

        // Award civic points the first time a report reaches COMPLETED.
        if (status.toUpperCase() == 'COMPLETED' && !wasAlreadyCompleted) {
          await _userRepository.incrementUserStats(
            r.userId,
            civicPointsDelta: AppConstants.pointsForReportResolution,
            resolvedComplaintsDelta: 1,
            pendingComplaintsDelta: -1,
          );
        }
      }

      return true;
    } catch (e) {
      _errorMessage = 'Failed to update status: $e';
      notifyListeners();
      return false;
    }
  }

  // ── User management ────────────────────────────────────────────────────────
  Future<bool> deleteUser(String userId) async {
    try {
      await _db.collection('users').doc(userId).delete();
      _users.removeWhere((u) => u['id'] == userId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete user: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(userId).update(data);
      final idx = _users.indexWhere((u) => u['id'] == userId);
      if (idx != -1) _users[idx] = {..._users[idx], ...data};
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update user: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Worker management ──────────────────────────────────────────────────────
  Future<bool> addWorker(Map<String, dynamic> workerData) async {
    try {
      final ref = await _db.collection('workers').add({
        ...workerData,
        'createdAt': FieldValue.serverTimestamp(),
      });
      // Also resolve effectiveAuthUid for the newly added worker
      final effectiveAuthUid = _resolveAuthUid(workerData, ref.id);
      _workers.add({
        'id':               ref.id,
        'effectiveAuthUid': effectiveAuthUid,
        ...workerData,
      });
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to add worker: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteWorker(String workerId) async {
    try {
      await _db.collection('workers').doc(workerId).delete();
      _workers.removeWhere((w) => w['id'] == workerId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete worker: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  List<Map<String, dynamic>> _workerMessages = [];
  List<Map<String, dynamic>> get workerMessages => _workerMessages;
  int get unreadMessageCount => _workerMessages.where((m) => m['isRead'] == false).length;

  StreamSubscription<QuerySnapshot>? _messagesSubscription;

  void listenToWorkerMessages() {
    _messagesSubscription?.cancel();
    _messagesSubscription = _db
        .collection('worker_messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .listen((snap) {
      _workerMessages = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      notifyListeners();
    });
  }

  Future<void> markMessageRead(String messageId) async {
    await _db.collection('worker_messages').doc(messageId).update({'isRead': true});
  }
  @override
  void dispose() {
    _reportsSubscription?.cancel();
    _messagesSubscription?.cancel();
    super.dispose();
  }
}