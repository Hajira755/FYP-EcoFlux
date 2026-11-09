// lib/services/local_report_service.dart
//
// Thin wrapper around the Hive box that stores offline-pending reports.
// This is the ONLY place that talks to Hive directly.
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';   // ← 'hive/hive.dart' ki jagah
import '../models/pending_report_model.dart';
import '../models/sync_status.dart';


class LocalReportService {
  static const String boxName = 'pending_reports';

  Box<PendingReportModel> get _box =>
      Hive.box<PendingReportModel>(boxName);

  /// Call once at app startup, AFTER Hive.initFlutter() + adapter registration.
  static Future<void> openBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox<PendingReportModel>(boxName);
    }
  }

  /// Exposes the box's listenable so the UI can react live to any change
  /// (new report added, status flips pending → uploading → synced, etc.)
  ValueListenable<Box<PendingReportModel>> listenable() => _box.listenable();

  Future<void> save(PendingReportModel report) async {
    await _box.put(report.localId, report);
  }

  PendingReportModel? get(String localId) => _box.get(localId);

  List<PendingReportModel> getAll() => _box.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  List<PendingReportModel> getUnsynced() => _box.values
      .where((r) => r.status != SyncStatus.synced)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<PendingReportModel> getSyncableNow({int maxRetries = 8}) => _box.values
      .where((r) =>
  (r.status == SyncStatus.pending) ||
      (r.status == SyncStatus.failed && r.retryCount < maxRetries))
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> updateStatus(
      String localId, {
        required SyncStatus status,
        String? errorMessage,
        int? retryCount,
        DateTime? syncedAt,
      }) async {
    final report = _box.get(localId);
    if (report == null) return;
    report.status       = status;
    if (errorMessage != null || status != SyncStatus.failed) {
      report.errorMessage = errorMessage;
    }
    if (retryCount != null) report.retryCount = retryCount;
    if (syncedAt   != null) report.syncedAt   = syncedAt;
    await _box.put(localId, report); // persist the mutated object back
  }

  Future<void> delete(String localId) async => _box.delete(localId);

  /// Housekeeping: remove old synced entries so the box doesn't grow forever.
  Future<void> purgeOldSynced({Duration olderThan = const Duration(days: 3)}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final toDelete = _box.values
        .where((r) =>
    r.status == SyncStatus.synced &&
        r.syncedAt != null &&
        r.syncedAt!.isBefore(cutoff))
        .map((r) => r.localId)
        .toList();
    for (final id in toDelete) {
      await _box.delete(id);
    }
  }

  int get pendingCount =>
      _box.values.where((r) => r.status == SyncStatus.pending).length;
  int get uploadingCount =>
      _box.values.where((r) => r.status == SyncStatus.uploading).length;
  int get failedCount =>
      _box.values.where((r) => r.status == SyncStatus.failed).length;
}