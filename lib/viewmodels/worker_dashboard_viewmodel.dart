// lib/viewmodels/worker_dashboard_viewmodel.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../models/complaint_model.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_repository.dart';
import '../services/notification_service.dart';
import '../core/constants/app_constants.dart';

class WorkerDashboardViewModel extends ChangeNotifier {
  final ReportRepository  _reportRepository = GetIt.instance<ReportRepository>();
  final UserRepository    _userRepository   = GetIt.instance<UserRepository>();
  final NotificationService _notificationService = NotificationService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool    _isLoading   = false;
  String? _errorMessage;
  String? _listeningWorkerId;

  List<ComplaintModel>   _assignedReports = [];
  Map<String, dynamic>?  _workerProfile;

  StreamSubscription<QuerySnapshot>? _reportsSubscription;

  bool    get isLoading     => _isLoading;
  String? get errorMessage  => _errorMessage;
  Map<String, dynamic>? get workerProfile => _workerProfile;

  List<ComplaintModel> get assignedReports  => _assignedReports;
  List<ComplaintModel> get pendingReports   => _assignedReports
      .where((r) => ['PENDING', 'ASSIGNED'].contains(r.status.toUpperCase()))
      .toList();
  List<ComplaintModel> get activeReports    => _assignedReports
      .where((r) => r.status.toUpperCase() == 'IN_PROGRESS')
      .toList();
  List<ComplaintModel> get completedReports => _assignedReports
      .where((r) => r.status.toUpperCase() == 'COMPLETED')
      .toList();

  int get totalAssigned  => _assignedReports.length;
  int get totalCompleted => completedReports.length;
  int get totalPending   => pendingReports.length + activeReports.length;

  // ── Load worker profile ────────────────────────────────────────────────────
  Future<void> loadWorkerProfile(String authUid) async {
    try {
      // 1. Try workers collection by workerId field
      final byWorkerId = await _db
          .collection('workers')
          .where('workerId', isEqualTo: authUid)
          .limit(1)
          .get();

      if (byWorkerId.docs.isNotEmpty) {
        final doc = byWorkerId.docs.first;
        _workerProfile = {'id': doc.id, 'authUid': authUid, ...doc.data()};
        debugPrint('WorkerVM: profile loaded via workerId field, docId=${doc.id}');
        notifyListeners();
        return;
      }

      // 2. Fallback: try authUid field
      final byAuthUid = await _db
          .collection('workers')
          .where('authUid', isEqualTo: authUid)
          .limit(1)
          .get();

      if (byAuthUid.docs.isNotEmpty) {
        final doc = byAuthUid.docs.first;
        _workerProfile = {'id': doc.id, 'authUid': authUid, ...doc.data()};
        debugPrint('WorkerVM: profile loaded via authUid field, docId=${doc.id}');
        notifyListeners();
        return;
      }

      // 3. Fallback: document ID == authUid
      final directDoc = await _db.collection('workers').doc(authUid).get();
      if (directDoc.exists) {
        _workerProfile = {
          'id': directDoc.id,
          'authUid': authUid,
          ...directDoc.data()!,
        };
        debugPrint('WorkerVM: profile loaded via direct doc ID');
        notifyListeners();
        return;
      }

      // 4. Last resort: users collection
      final userDoc = await _db.collection('users').doc(authUid).get();
      if (userDoc.exists) {
        _workerProfile = {
          'id': userDoc.id,
          'authUid': authUid,
          ...userDoc.data()!,
        };
        debugPrint('WorkerVM: profile loaded from users collection');
        notifyListeners();
      } else {
        debugPrint('WorkerVM: NO profile found for authUid=$authUid');
      }
    } catch (e) {
      debugPrint('WorkerVM loadWorkerProfile error: $e');
    }
  }

  // ── Real-time stream ───────────────────────────────────────────────────────
  void listenToAssignedReports(String authUid) {
    if (_listeningWorkerId == authUid && _reportsSubscription != null) {
      debugPrint('WorkerVM: already listening for $authUid');
      return;
    }

    _reportsSubscription?.cancel();
    _listeningWorkerId = authUid;
    _isLoading = true;
    notifyListeners();

    debugPrint('WorkerVM: starting reports stream for authUid=$authUid');

    _reportsSubscription = _reportRepository
        .getWorkerAssignedReports(authUid)
        .listen(
          (snapshot) {
        debugPrint('WorkerVM: received ${snapshot.docs.length} reports');

        _assignedReports = snapshot.docs.map((doc) {
          return ComplaintModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList()
          ..sort((a, b) {
            int score(ComplaintModel r) {
              if (r.status.toUpperCase() == 'ESCALATED') return 0;
              if (r.priority.toLowerCase() == 'high')    return 1;
              if (r.priority.toLowerCase() == 'medium')  return 2;
              if (r.status.toUpperCase() == 'COMPLETED') return 10;
              return 3;
            }
            return score(a).compareTo(score(b));
          });

        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        debugPrint('WorkerVM stream error: $e');
        _errorMessage = e.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  // ── Update status ──────────────────────────────────────────────────────────
  Future<bool> updateReportStatus(String reportId, String status) async {
    try {
      final wasAlreadyCompleted = _isAlreadyCompleted(reportId);
      await _reportRepository.updateComplaintStatus(reportId, status);
      await _notifyCitizenIfKnown(reportId, status);
      await _awardPointsIfNewlyCompleted(reportId, status, wasAlreadyCompleted);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update status: $e';
      notifyListeners();
      return false;
    }
  }

  bool _isAlreadyCompleted(String reportId) {
    final matches = _assignedReports.where((r) => r.complaintId == reportId);
    return matches.isNotEmpty &&
        matches.first.status.toUpperCase() == 'COMPLETED';
  }

  /// Shared helper: looks up the report in the worker's already-loaded
  /// assigned-reports list (so no extra Firestore read is needed) and
  /// fires a status-update notification to the citizen who filed it.
  Future<void> _notifyCitizenIfKnown(String reportId, String status) async {
    final matches = _assignedReports.where((r) => r.complaintId == reportId);
    if (matches.isEmpty) return;
    final r = matches.first;
    await _notificationService.notifyCitizenStatusUpdate(
      citizenId: r.userId,
      reportCategory: r.category,
      newStatus: status,
      reportId: reportId,
    );
  }

  /// Awards civic points to the citizen the FIRST time a report reaches
  /// COMPLETED. `wasAlreadyCompleted` must be captured BEFORE the status
  /// write happens, otherwise this could double-award on repeat taps.
  Future<void> _awardPointsIfNewlyCompleted(
      String reportId,
      String status,
      bool wasAlreadyCompleted,
      ) async {
    if (status.toUpperCase() != 'COMPLETED' || wasAlreadyCompleted) return;
    final matches = _assignedReports.where((r) => r.complaintId == reportId);
    if (matches.isEmpty) return;
    final r = matches.first;
    await _userRepository.incrementUserStats(
      r.userId,
      civicPointsDelta: AppConstants.pointsForReportResolution,
      resolvedComplaintsDelta: 1,
      pendingComplaintsDelta: -1,
    );
  }

  // ── Resolve report — completedImageUrl is now optional (may be empty) ──────
  Future<bool> resolveReport({
    required String reportId,
    String completedImageUrl = '',   // optional — pass '' if no photo
  }) async {
    try {
      final wasAlreadyCompleted = _isAlreadyCompleted(reportId);
      await _reportRepository.updateComplaintStatus(
        reportId,
        'COMPLETED',
        completedImageUrl: completedImageUrl.isNotEmpty
            ? completedImageUrl
            : null,
      );
      await _notifyCitizenIfKnown(reportId, 'COMPLETED');
      await _awardPointsIfNewlyCompleted(
          reportId, 'COMPLETED', wasAlreadyCompleted);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to resolve report: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Send help message to admin ─────────────────────────────────────────────
  // NOTE: The "Failed to send" error was NOT caused by this method —
  // it was caused by the caller (_showHelpSheet) using the bottom sheet's
  // anonymous BuildContext to look up providers, which fails because that
  // context has no Provider ancestors. The fix is in worker_report_detail_screen.dart
  // where providers are now captured BEFORE the sheet opens.
  //
  // This method logs the full exception so future errors are easy to diagnose.
  Future<bool> sendHelpMessage({
    required String workerId,
    required String workerName,
    required String reportId,
    required String message,
  }) async {
    try {
      debugPrint('WorkerVM: sending help message from workerId=$workerId '
          'reportId=$reportId');
      await _db.collection('worker_messages').add({
        'workerId':   workerId,
        'workerName': workerName,
        'reportId':   reportId,
        'message':    message,
        'isRead':     false,
        'timestamp':  FieldValue.serverTimestamp(),
      });
      debugPrint('WorkerVM: help message sent successfully');

      // Alert every admin so the help request doesn't just sit unseen in
      // the worker_messages collection until someone happens to open it.
      await _notificationService.notifyAdminHelpRequest(
        workerName: workerName,
        reportId: reportId,
        message: message,
      );

      _errorMessage = null;
      return true;
    } catch (e) {
      // Log the full error so you can diagnose Firestore permission issues
      debugPrint('WorkerVM sendHelpMessage ERROR: $e');
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ── Update worker profile ──────────────────────────────────────────────────
  Future<bool> updateProfile(String workerId, Map<String, dynamic> data) async {
    try {
      await _db.collection('workers').doc(workerId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _workerProfile = {...?_workerProfile, ...data};
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update profile: $e';
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void refreshData() => notifyListeners();

  @override
  void dispose() {
    _reportsSubscription?.cancel();
    super.dispose();
  }
}