// lib/widgets/sync_status_banner.dart
//
// Slim banner shown on the Citizen Dashboard. Hidden entirely when there's
// nothing to report. Tap it to open the Offline Queue screen.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/sync_viewmodel.dart';
import '../core/navigation/app_routes.dart';

const _kGreen  = Color(0xFF2E7D32);
const _kOrange = Color(0xFFE65100);
const _kRed    = Color(0xFFC62828);

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final syncVM = Provider.of<SyncViewModel>(context);

    if (syncVM.queueLength == 0) return const SizedBox.shrink();

    late final Color   color;
    late final IconData icon;
    late final String   text;

    if (syncVM.failedCount > 0) {
      color = _kRed;
      icon  = Icons.error_outline_rounded;
      text  = '${syncVM.failedCount} report${syncVM.failedCount > 1 ? 's' : ''} '
          'failed to upload — tap to retry';
    } else if (!syncVM.isOnline) {
      color = _kOrange;
      icon  = Icons.cloud_off_rounded;
      text  = '${syncVM.queueLength} report${syncVM.queueLength > 1 ? 's' : ''} '
          'saved offline — will upload when you\'re back online';
    } else if (syncVM.isSyncing || syncVM.uploadingCount > 0) {
      color = _kGreen;
      icon  = Icons.cloud_sync_rounded;
      text  = 'Uploading ${syncVM.queueLength} report'
          '${syncVM.queueLength > 1 ? 's' : ''}…';
    } else {
      color = _kOrange;
      icon  = Icons.schedule_rounded;
      text  = '${syncVM.queueLength} report${syncVM.queueLength > 1 ? 's' : ''} '
          'waiting to sync';
    }

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, AppRoutes.offlineQueue),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            if (syncVM.isSyncing || syncVM.uploadingCount > 0)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}