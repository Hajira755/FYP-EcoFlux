// lib/models/sync_status.dart

/// Lifecycle of a locally-saved report until it lands safely in Firestore.
enum SyncStatus {
  pending,   // saved locally, waiting for internet
  uploading, // sync in progress right now
  synced,    // successfully written to Firestore
  failed,    // upload attempt(s) failed — will retry automatically
}

extension SyncStatusX on SyncStatus {
  String get label {
    switch (this) {
      case SyncStatus.pending:
        return 'Pending';
      case SyncStatus.uploading:
        return 'Uploading';
      case SyncStatus.synced:
        return 'Synced';
      case SyncStatus.failed:
        return 'Failed';
    }
  }
}