// lib/viewmodels/sync_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../models/pending_report_model.dart';
import '../services/local_report_service.dart';
import '../services/sync_service.dart';

class SyncViewModel extends ChangeNotifier {
  final LocalReportService _localReportService = GetIt.instance<LocalReportService>();
  final SyncService        _syncService         = GetIt.instance<SyncService>();

  SyncViewModel() {
    // Re-emit whenever the Hive box changes (new report, status flip, etc.)
    _localReportService.listenable().addListener(notifyListeners);
    // Re-emit whenever the sync engine's global isSyncing/isOnline flags change.
    _syncService.addListener(notifyListeners);
  }

  bool get isSyncing => _syncService.isSyncing;
  bool get isOnline  => _syncService.isOnline;

  List<PendingReportModel> get allLocalReports => _localReportService.getAll();
  List<PendingReportModel> get unsyncedReports => _localReportService.getUnsynced();

  int get pendingCount   => _localReportService.pendingCount;
  int get uploadingCount => _localReportService.uploadingCount;
  int get failedCount    => _localReportService.failedCount;
  int get queueLength    => pendingCount + uploadingCount + failedCount;

  Future<void> retry(String localId) => _syncService.retrySingle(localId);

  Future<void> retryAll() => _syncService.syncPendingReports();

  @override
  void dispose() {
    _localReportService.listenable().removeListener(notifyListeners);
    _syncService.removeListener(notifyListeners);
    super.dispose();
  }
}