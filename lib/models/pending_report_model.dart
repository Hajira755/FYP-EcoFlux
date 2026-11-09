// lib/models/pending_report_model.dart
//
// A locally-persisted report waiting to be synced to Firestore.
// Stored in Hive so it survives app restarts / crashes before sync.
//
// TypeAdapters below are written BY HAND (no build_runner / hive_generator
// needed) — this keeps the FYP setup simple with zero code-gen steps.

import 'package:hive/hive.dart';
import 'sync_status.dart';

class PendingReportModel {
  final String     localId;      // == the Firestore complaintId (see below)
  final String     userId;
  final String     description;
  final String     category;
  final String     priority;
  final double?     latitude;
  final double?     longitude;
  final String      address;
  final String?     imageBase64; // 'data:image/jpeg;base64,...' or null
  final DateTime    createdAt;

  SyncStatus status;
  int        retryCount;
  String?    errorMessage;
  DateTime?  syncedAt;

  PendingReportModel({
    required this.localId,
    required this.userId,
    required this.description,
    required this.category,
    required this.priority,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.imageBase64,
    required this.createdAt,
    this.status = SyncStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
    this.syncedAt,
  });
}

// ─────────────────────────────────────────────────────────────────────────
//  Hive TypeAdapters — hand-written, no build_runner required
// ─────────────────────────────────────────────────────────────────────────

/// typeId 0
class PendingReportModelAdapter extends TypeAdapter<PendingReportModel> {
  @override
  final int typeId = 0;

  @override
  PendingReportModel read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numFields; i++) reader.readByte(): reader.read(),
    };

    return PendingReportModel(
      localId:      fields[0] as String,
      userId:       fields[1] as String,
      description:  fields[2] as String,
      category:     fields[3] as String,
      priority:     fields[4] as String,
      latitude:     fields[5] as double?,
      longitude:    fields[6] as double?,
      address:      fields[7] as String,
      imageBase64:  fields[8] as String?,
      createdAt:    fields[9] as DateTime,
      status:       SyncStatus.values[fields[10] as int],
      retryCount:   fields[11] as int,
      errorMessage: fields[12] as String?,
      syncedAt:     fields[13] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, PendingReportModel obj) {
    writer
      ..writeByte(14) // number of fields
      ..writeByte(0)  ..write(obj.localId)
      ..writeByte(1)  ..write(obj.userId)
      ..writeByte(2)  ..write(obj.description)
      ..writeByte(3)  ..write(obj.category)
      ..writeByte(4)  ..write(obj.priority)
      ..writeByte(5)  ..write(obj.latitude)
      ..writeByte(6)  ..write(obj.longitude)
      ..writeByte(7)  ..write(obj.address)
      ..writeByte(8)  ..write(obj.imageBase64)
      ..writeByte(9)  ..write(obj.createdAt)
      ..writeByte(10) ..write(obj.status.index)
      ..writeByte(11) ..write(obj.retryCount)
      ..writeByte(12) ..write(obj.errorMessage)
      ..writeByte(13) ..write(obj.syncedAt);
  }
}