// lib/services/sync_service.dart
//
// The engine behind offline-first reporting.
//   • queueNewReport()      -> called by ComplaintViewModel when the user
//                              submits a report (works with or without net).
//   • syncPendingReports()  -> uploads everything that's waiting, in order.
//   • Auto-runs whenever connectivity flips from offline -> online, and on
//     a periodic timer (covers "connected but flaky" situations).

import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/complaint_model.dart';
import '../models/pending_report_model.dart';
import '../models/sync_status.dart';
import '../repositories/report_repository.dart';
import '../repositories/user_repository.dart';
import '../core/constants/app_constants.dart';
import 'connectivity_service.dart';
import 'local_report_service.dart';
import 'storage_service.dart';

class SyncService extends ChangeNotifier {
  final ReportRepository     _reportRepository;
  final StorageService       _storageService;
  final LocalReportService   _localReportService;
  final ConnectivityService  _connectivityService;
  final UserRepository       _userRepository;

  static const int _maxRetries = 8;

  StreamSubscription<bool>? _connectivitySub;
  Timer? _periodicTimer;
  bool _isSyncing = false;
  bool _isOnline = true;

  SyncService({
    required ReportRepository    reportRepository,
    required StorageService      storageService,
    required LocalReportService  localReportService,
    required ConnectivityService connectivityService,
    required UserRepository      userRepository,
  })  : _reportRepository    = reportRepository,
        _storageService       = storageService,
        _localReportService   = localReportService,
        _connectivityService  = connectivityService,
        _userRepository       = userRepository;

  bool get isSyncing => _isSyncing;
  bool get isOnline  => _isOnline;

  /// Call once at app startup (after GetIt + Hive are ready).
  void start() {
    _connectivitySub = _connectivityService.onStatusChange.listen((online) {
      final wasOffline = !_isOnline;
      _isOnline = online;
      if (online && wasOffline) {
        debugPrint('SyncService: connectivity restored — syncing now');
        syncPendingReports();
      }
    });

    // Safety-net: retry every 45s if there's anything left to sync
    // (covers "connected but request silently failed" cases).
    _periodicTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (_localReportService.getSyncableNow(maxRetries: _maxRetries).isNotEmpty) {
        syncPendingReports();
      }
    });

    // Kick off an initial attempt in case there's already a backlog
    // from a previous session that never finished syncing.
    syncPendingReports();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _periodicTimer?.cancel();
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Step 1 — save a brand-new report locally (works fully offline)
  // ───────────────────────────────────────────────────────────────────────
  Future<void> queueNewReport({
    required String  description,
    required String  category,
    required String  priority,
    required double?  latitude,
    required double?  longitude,
    required String   address,
    Uint8List?        imageBytes,
    required String   userId,
  }) async {
    // The Firestore SDK can mint a document ID entirely client-side —
    // no network call needed — and re-using this SAME id at sync time
    // (via .set()) is what guarantees we never create a duplicate report
    // even if syncing is retried multiple times.
    final localId = _reportRepository.generateNewComplaintId();

    String? imageBase64;
    if (imageBytes != null) {
      // Pure local bytes -> base64 encode — no internet required, and this
      // works identically on Android, iOS, and Flutter Web.
      imageBase64 = await _storageService.uploadComplaintImage(imageBytes, userId);
    }

    final report = PendingReportModel(
      localId:     localId,
      userId:      userId,
      description: description,
      category:    category,
      priority:    priority,
      latitude:    latitude,
      longitude:   longitude,
      address:     address,
      imageBase64: imageBase64,
      createdAt:   DateTime.now(),
      status:      SyncStatus.pending,
    );

    await _localReportService.save(report);
    notifyListeners();

    // Try to upload immediately — if we're offline this simply fails
    // fast and the report stays safely queued as "pending".
    unawaited(syncPendingReports());
  }

  // ───────────────────────────────────────────────────────────────────────
  //  Step 2 — upload everything that's waiting
  // ───────────────────────────────────────────────────────────────────────
  Future<void> syncPendingReports() async {
    if (_isSyncing) return; // prevent overlapping sync runs
    final online = await _connectivityService.hasConnection();
    _isOnline = online;
    if (!online) return;

    final queue = _localReportService.getSyncableNow(maxRetries: _maxRetries);
    if (queue.isEmpty) return;

    _isSyncing = true;
    notifyListeners();

    for (final report in queue) {
      await _uploadSingle(report);
    }

    await _localReportService.purgeOldSynced();

    _isSyncing = false;
    notifyListeners();
  }

  Future<bool> _uploadSingle(PendingReportModel report) async {
    await _localReportService.updateStatus(
      report.localId,
      status: SyncStatus.uploading,
    );
    notifyListeners();

    try {
      final complaint = ComplaintModel(
        complaintId: report.localId, // SAME id used offline -> idempotent write
        userId:      report.userId,
        description: report.description,
        category:    report.category,
        priority:    report.priority,
        location: (report.latitude != null && report.longitude != null)
            ? GeoPoint(report.latitude!, report.longitude!)
            : null,
        address:   report.address,
        imageUrl:  report.imageBase64,
        status:    'PENDING',
        timestamp: Timestamp.fromDate(report.createdAt),
      );

      // .set() on the same document id => safe to call more than once,
      // it will never create a duplicate complaint.
      await _reportRepository.submitComplaint(complaint);

      // Award civic points for filing the report. This only runs once per
      // report — once status flips to `synced` below, _uploadSingle is
      // never called again for this localId (getSyncableNow only returns
      // pending/failed items), so there's no risk of double-awarding on
      // retries. A failure here is logged but never rethrown — the report
      // itself already uploaded successfully and must not be marked failed
      // just because the points update had a hiccup.
      try {
        await _userRepository.incrementUserStats(
          report.userId,
          civicPointsDelta: AppConstants.pointsForReportSubmission,
          totalComplaintsDelta: 1,
          pendingComplaintsDelta: 1,
        );
      } catch (e) {
        debugPrint('SyncService: civic points update failed (non-fatal): $e');
      }

      await _localReportService.updateStatus(
        report.localId,
        status: SyncStatus.synced,
        syncedAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('SyncService: upload failed for ${report.localId}: $e');
      await _localReportService.updateStatus(
        report.localId,
        status: SyncStatus.failed,
        errorMessage: e.toString(),
        retryCount: report.retryCount + 1,
      );
      notifyListeners();
      return false;
    }
  }

  /// Manual retry button on the Offline Queue screen.
  Future<void> retrySingle(String localId) async {
    final report = _localReportService.get(localId);
    if (report == null) return;
    await _localReportService.updateStatus(localId, status: SyncStatus.pending);
    notifyListeners();
    await syncPendingReports();
  }
}