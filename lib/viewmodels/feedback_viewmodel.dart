import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../models/feedback_model.dart';
import '../models/complaint_model.dart';
import '../repositories/feedback_repository.dart';
import '../repositories/report_repository.dart';
import '../services/notification_service.dart';

class FeedbackViewModel extends ChangeNotifier {
  final FeedbackRepository _feedbackRepository = GetIt.instance<FeedbackRepository>();
  final ReportRepository _reportRepository = GetIt.instance<ReportRepository>();
  final NotificationService _notificationService = NotificationService();

  bool _isSubmitting = false;
  String? _errorMessage;

  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> submitFeedback({
    required int rating,
    required String comment,
    required String userId,
    required String userName,
    String? reportId,        // NEW — pass the complaint's ID when giving
    // feedback about a specific report
    String? reportCategory,  // NEW — optional, just for display later
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final String feedbackId = _feedbackRepository.generateNewFeedbackId();

      final feedback = FeedbackModel(
        feedbackId: feedbackId,
        userId: userId,
        userName: userName,
        rating: rating,
        comment: comment,
        reportId: reportId,             // NEW
        reportCategory: reportCategory, // NEW
      );

      await _feedbackRepository.submitFeedback(feedback);

      // NEW — if this feedback is about a specific report, find out who
      // resolved it and let them know a citizen left feedback. Previously
      // this information never reached the worker in any form.
      if (reportId != null && reportId.isNotEmpty) {
        try {
          final snap = await _reportRepository.getComplaintById(reportId).first;
          if (snap.exists) {
            final report = ComplaintModel.fromMap(
              snap.data() as Map<String, dynamic>,
              snap.id,
            );
            final workerId = report.assignedWorkerId;
            if (workerId != null && workerId.isNotEmpty) {
              await _notificationService.notifyWorkerFeedback(
                workerId: workerId,
                rating: rating,
                reportCategory: reportCategory ?? report.category,
                reportId: reportId,
              );
            }
          }
        } catch (e) {
          // Don't fail the whole feedback submission just because the
          // notification step failed (e.g. report was deleted meanwhile).
          debugPrint('FeedbackViewModel: worker notify failed: $e');
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to submit feedback: ${e.toString()}';
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// NEW — call this before showing the feedback form for a report, so you
  /// can hide/disable the button if feedback was already given once.
  Future<bool> hasFeedbackForReport(String reportId) {
    return _feedbackRepository.hasFeedbackForReport(reportId);
  }
}