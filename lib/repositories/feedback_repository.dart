import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/feedback_model.dart';

class FeedbackRepository {
  final FirestoreService _firestoreService;

  FeedbackRepository(this._firestoreService);

  String generateNewFeedbackId() => _firestoreService.generateNewFeedbackId();

  Future<void> submitFeedback(FeedbackModel feedback) {
    return _firestoreService.submitFeedback(feedback);
  }

  Stream<QuerySnapshot> getAllFeedback() {
    return _firestoreService.getAllFeedback();
  }

  Stream<QuerySnapshot> getFeedbackForReport(String reportId) {
    return _firestoreService.getFeedbackForReport(reportId);
  }

  Future<bool> hasFeedbackForReport(String reportId) {
    return _firestoreService.hasFeedbackForReport(reportId);
  }
}
