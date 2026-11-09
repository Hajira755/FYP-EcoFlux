// lib/viewmodels/complaint_viewmodel.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../models/complaint_model.dart';
import '../repositories/report_repository.dart';
import '../services/sync_service.dart';

class ComplaintViewModel extends ChangeNotifier {
  final ReportRepository _reportRepository = GetIt.instance<ReportRepository>();
  final SyncService       _syncService      = GetIt.instance<SyncService>();

  bool    _isLoading    = false;
  String? _errorMessage;
  List<ComplaintModel> _userComplaints = [];

  // ── Keep track of the active subscription so we never double-subscribe ──────
  StreamSubscription<QuerySnapshot>? _complaintsSubscription;
  String? _listeningUserId; // track which user we're already listening for

  bool    get isLoading     => _isLoading;
  String? get errorMessage  => _errorMessage;
  List<ComplaintModel> get userComplaints => _userComplaints;

  // Derived counts — dashboard reads these directly from the live list
  int get totalComplaints   => _userComplaints.length;
  int get resolvedComplaints =>
      _userComplaints.where((c) => c.status.toUpperCase() == 'COMPLETED').length;
  int get pendingComplaints  =>
      _userComplaints.where((c) =>
      c.status.toUpperCase() == 'PENDING' ||
          c.status.toUpperCase() == 'ESCALATED').length;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Submit New Report — OFFLINE-FIRST ───────────────────────────────────────
  // The report is ALWAYS saved locally first (via SyncService), so it is
  // never lost even if there's no internet or the app is closed right
  // after submitting. SyncService then uploads it automatically — right
  // away if online, or as soon as connectivity returns.
  Future<void> submitNewComplaint({
    required String    description,
    required String    category,
    required String    priority,
    required GeoPoint? location,
    required String    address,
    Uint8List?         imageBytes,
    required String    userId,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _syncService.queueNewReport(
        description: description,
        category:    category,
        priority:    priority,
        latitude:    location?.latitude,
        longitude:   location?.longitude,
        address:     address,
        imageBytes:  imageBytes,
        userId:      userId,
      );
      _errorMessage = null;
    } catch (e) {
      // This only fails on a genuine local-storage error (e.g. disk full) —
      // network problems never reach here, they're handled by SyncService.
      _errorMessage = 'Failed to save report: ${e.toString()}';
      debugPrint('submitNewComplaint error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Real-time listener ──────────────────────────────────────────────────────
  /// Call this once when the dashboard loads.
  /// Safe to call multiple times — it cancels any previous subscription first
  /// so you never get duplicate listeners or stale data.
  void listenToUserComplaints(String userId) {
    // If already listening for this same user, do nothing
    if (_listeningUserId == userId && _complaintsSubscription != null) {
      debugPrint('ComplaintViewModel: already listening for $userId');
      return;
    }

    // Cancel old subscription before creating a new one
    _complaintsSubscription?.cancel();
    _listeningUserId = userId;

    debugPrint('ComplaintViewModel: starting stream for $userId');

    _complaintsSubscription = _reportRepository
        .getUserComplaints(userId)
        .listen(
          (snapshot) {
        debugPrint(
            'ComplaintViewModel: snapshot received — ${snapshot.docs.length} docs');

        _userComplaints = snapshot.docs.map((doc) {
          return ComplaintModel.fromMap(
            doc.data() as Map<String, dynamic>,
            doc.id,
          );
        }).toList();

        // Sort newest first in-memory (avoids Firestore composite index requirement)
        _userComplaints.sort((a, b) {
          final ta = a.timestamp?.toDate() ?? DateTime(0);
          final tb = b.timestamp?.toDate() ?? DateTime(0);
          return tb.compareTo(ta);
        });

        _errorMessage = null;
        notifyListeners();
      },
      onError: (error) {
        debugPrint('ComplaintViewModel stream error: $error');
        _errorMessage = error.toString();
        notifyListeners();
      },
    );
  }

  // ── Track single report ─────────────────────────────────────────────────────
  Stream<DocumentSnapshot> getComplaintStream(String complaintId) {
    return _reportRepository.getComplaintById(complaintId);
  }

  // ── Cleanup ─────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _complaintsSubscription?.cancel();
    super.dispose();
  }
}