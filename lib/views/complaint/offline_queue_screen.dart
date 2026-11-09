// lib/views/complaint/offline_queue_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/pending_report_model.dart';
import '../../models/sync_status.dart';
import '../../viewmodels/sync_viewmodel.dart';
import '../../widgets/smart_image.dart';

const _kGreen  = Color(0xFF2E7D32);
const _kOrange = Color(0xFFE65100);
const _kRed    = Color(0xFFC62828);
const _kBlue   = Color(0xFF1565C0);
const _kBg     = Color(0xFFF4F6F9);

class OfflineQueueScreen extends StatelessWidget {
  const OfflineQueueScreen({super.key});

  Color _statusColor(SyncStatus s) {
    switch (s) {
      case SyncStatus.synced:    return _kGreen;
      case SyncStatus.uploading: return _kBlue;
      case SyncStatus.failed:    return _kRed;
      case SyncStatus.pending:   return _kOrange;
    }
  }

  IconData _statusIcon(SyncStatus s) {
    switch (s) {
      case SyncStatus.synced:    return Icons.check_circle_rounded;
      case SyncStatus.uploading: return Icons.cloud_upload_rounded;
      case SyncStatus.failed:    return Icons.error_rounded;
      case SyncStatus.pending:   return Icons.schedule_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncVM = Provider.of<SyncViewModel>(context);
    final reports = syncVM.allLocalReports;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Offline Report Queue',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: _kGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (syncVM.failedCount > 0 || syncVM.pendingCount > 0)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Retry all',
              onPressed: () => syncVM.retryAll(),
            ),
        ],
      ),
      body: reports.isEmpty
          ? _EmptyState()
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _QueueTile(
          report: reports[i],
          color:  _statusColor(reports[i].status),
          icon:   _statusIcon(reports[i].status),
          onRetry: () => syncVM.retry(reports[i].localId),
        ),
      ),
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    required this.report,
    required this.color,
    required this.icon,
    required this.onRetry,
  });

  final PendingReportModel report;
  final Color   color;
  final IconData icon;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: report.imageBase64 != null
                ? SmartImage(report.imageBase64!,
                height: 56, width: 56, fit: BoxFit.cover)
                : Container(
              height: 56,
              width: 56,
              color: Colors.grey[200],
              child: const Icon(Icons.image_not_supported_outlined,
                  color: Colors.grey, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.category,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  report.description.isNotEmpty
                      ? report.description
                      : 'No description',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, color: color, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            report.status.label,
                            style: TextStyle(
                                color: color,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    if (report.status == SyncStatus.failed &&
                        report.retryCount > 0) ...[
                      const SizedBox(width: 6),
                      Text('${report.retryCount} attempt(s)',
                          style: TextStyle(
                              fontSize: 10.5, color: Colors.grey[400])),
                    ],
                  ],
                ),
                if (report.status == SyncStatus.failed &&
                    report.errorMessage != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    report.errorMessage!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10.5, color: _kRed),
                  ),
                ],
              ],
            ),
          ),
          if (report.status == SyncStatus.failed)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _kGreen, size: 20),
              tooltip: 'Retry',
              onPressed: onRetry,
            )
          else if (report.status == SyncStatus.uploading)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Nothing to sync — all reports are up to date',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      ),
    );
  }
}