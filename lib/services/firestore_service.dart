// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';
import '../models/feedback_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _reportsCollection  = 'reports';
  static const String _feedbackCollection = 'feedback';
  static const String _usersCollection    = 'users';

  CollectionReference get _reportsRef  => _db.collection(_reportsCollection);
  CollectionReference get _feedbackRef => _db.collection(_feedbackCollection);
  CollectionReference get _usersRef    => _db.collection(_usersCollection);

  // ══════════════════════════════════════════════════════════════════════════
  //  REPORTS
  // ══════════════════════════════════════════════════════════════════════════

  String generateNewComplaintId() => _reportsRef.doc().id;

  Future<void> submitComplaint(ComplaintModel complaint) async {
    await _reportsRef.doc(complaint.complaintId).set(complaint.toMap());
  }

  /// No .orderBy() — sorting handled in ComplaintViewModel to avoid
  /// Firestore composite index requirement.
  Stream<QuerySnapshot> getUserComplaints(String userId) {
    return _reportsRef
        .where('userId', isEqualTo: userId)
        .snapshots();
  }

  Stream<DocumentSnapshot> getComplaintById(String complaintId) {
    return _reportsRef.doc(complaintId).snapshots();
  }

  Future<void> updateComplaintStatus(
      String complaintId,
      String status, {
        String? assignedWorkerId,
        String? assignedWorkerName,
        String? completedImageUrl,
      }) async {
    final Map<String, dynamic> data = {
      'status':      status,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
    if (assignedWorkerId   != null) data['assignedWorkerId']   = assignedWorkerId;
    if (assignedWorkerName != null) data['assignedWorkerName'] = assignedWorkerName;
    if (completedImageUrl  != null) data['completedImageUrl']  = completedImageUrl;

    await _reportsRef.doc(complaintId).update(data);
  }

  Future<void> assignWorkerToComplaint(
      String complaintId,
      String workerAuthUid,
      String workerName,
      ) async {
    await _reportsRef.doc(complaintId).update({
      'assignedWorkerId':   workerAuthUid,
      'assignedWorkerName': workerName,
      'status':             'ASSIGNED',
      'lastUpdated':        FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getAllComplaints() {
    return _reportsRef.snapshots();
  }

  Stream<QuerySnapshot> getComplaintsByStatus(String status) {
    return _reportsRef
        .where('status', isEqualTo: status)
        .snapshots();
  }

  Stream<QuerySnapshot> getWorkerAssignedReports(String workerAuthUid) {
    return _reportsRef
        .where('assignedWorkerId', isEqualTo: workerAuthUid)
        .snapshots();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FEEDBACK
  // ══════════════════════════════════════════════════════════════════════════

  String generateNewFeedbackId() => _feedbackRef.doc().id;

  Future<void> submitFeedback(FeedbackModel feedback) async {
    await _feedbackRef.doc(feedback.feedbackId).set(feedback.toMap());
  }

  Stream<QuerySnapshot> getAllFeedback() {
    return _feedbackRef
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ── NEW: feedback tied to one specific report ──────────────────────────────

  /// Stream of feedback entries submitted for one specific report.
  /// Useful on an admin/worker screen to show what a citizen said about
  /// that particular complaint.
  Stream<QuerySnapshot> getFeedbackForReport(String reportId) {
    return _feedbackRef
        .where('reportId', isEqualTo: reportId)
        .snapshots();
  }

  /// One-time check: has feedback already been given for this report?
  /// Used to hide/disable the "Give Feedback" button after it's been used
  /// once, so the same report can't be rated twice.
  Future<bool> hasFeedbackForReport(String reportId) async {
    final snap = await _feedbackRef
        .where('reportId', isEqualTo: reportId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  USERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<DocumentSnapshot> getUserData(String uid) {
    return _usersRef.doc(uid).get();
  }

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _usersRef.doc(uid).snapshots();
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) async {
    await _usersRef.doc(uid).update(data);
  }

  /// Atomically increments civic points / complaint counters on a user's
  /// document using FieldValue.increment — safe to call from multiple
  /// places without a read-then-write race condition, and works even if
  /// the fields don't exist yet on the doc (increment treats missing as 0).
  /// Pass only the deltas that actually changed; 0 (the default) is skipped
  /// so we don't write fields that didn't move.
  Future<void> incrementUserStats(
      String uid, {
        int civicPointsDelta = 0,
        int totalComplaintsDelta = 0,
        int resolvedComplaintsDelta = 0,
        int pendingComplaintsDelta = 0,
      }) async {
    final Map<String, dynamic> updates = {};
    if (civicPointsDelta != 0) {
      updates['civicPoints'] = FieldValue.increment(civicPointsDelta);
    }
    if (totalComplaintsDelta != 0) {
      updates['totalComplaints'] = FieldValue.increment(totalComplaintsDelta);
    }
    if (resolvedComplaintsDelta != 0) {
      updates['resolvedComplaints'] =
          FieldValue.increment(resolvedComplaintsDelta);
    }
    if (pendingComplaintsDelta != 0) {
      updates['pendingComplaints'] =
          FieldValue.increment(pendingComplaintsDelta);
    }
    if (updates.isEmpty) return;

    // set(..., merge: true) instead of update() — update() throws if the
    // user document (or these specific fields) don't exist yet, which
    // would be common right after signup before any report is ever filed.
    await _usersRef.doc(uid).set(updates, SetOptions(merge: true));
  }
}