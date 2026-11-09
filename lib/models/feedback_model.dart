import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackModel {
  final String feedbackId;
  final String userId;
  final String userName;
  final int rating; // 1 to 5
  final String comment;
  final Timestamp? timestamp;
  final String status; // pending, reviewed, etc.

  // ── NEW: ties this feedback to one specific complaint ──────────────────
  // Nullable so general "app feedback" (not about a specific report) still
  // works if you keep that entry point too.
  final String? reportId;
  final String? reportCategory; // e.g. "Overflowing Bin" — shown in lists

  FeedbackModel({
    required this.feedbackId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.timestamp,
    this.status = 'pending',
    this.reportId,        // NEW
    this.reportCategory,  // NEW
  });

  factory FeedbackModel.fromMap(Map<String, dynamic> map, String id) {
    return FeedbackModel(
      feedbackId: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? 'Anonymous',
      rating: map['rating'] ?? 0,
      comment: map['comment'] ?? '',
      timestamp: map['timestamp'] as Timestamp?,
      status: map['status'] ?? 'pending',
      reportId: map['reportId'] as String?,             // NEW
      reportCategory: map['reportCategory'] as String?, // NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'feedbackId': feedbackId,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'status': status,
      'reportId': reportId,             // NEW
      'reportCategory': reportCategory, // NEW
    };
  }
}