import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';
import '../models/complaint_model.dart';

class ReportRepository {
  final FirestoreService _firestoreService;

  ReportRepository(this._firestoreService);

  String generateNewComplaintId() => _firestoreService.generateNewComplaintId();

  Future<void> submitComplaint(ComplaintModel complaint) {
    return _firestoreService.submitComplaint(complaint);
  }

  Stream<QuerySnapshot> getUserComplaints(String userId) {
    return _firestoreService.getUserComplaints(userId);
  }

  Stream<DocumentSnapshot> getComplaintById(String complaintId) {
    return _firestoreService.getComplaintById(complaintId);
  }

  Future<void> updateComplaintStatus(
      String complaintId,
      String status, {
        String? assignedWorkerId,
        String? assignedWorkerName,
        String? completedImageUrl,
      }) {
    return _firestoreService.updateComplaintStatus(
      complaintId,
      status,
      assignedWorkerId: assignedWorkerId,
      assignedWorkerName: assignedWorkerName,
      completedImageUrl: completedImageUrl,
    );
  }

  Future<void> assignWorkerToComplaint(
      String complaintId,
      String workerAuthUid,
      String workerName,
      ) {
    return _firestoreService.assignWorkerToComplaint(
      complaintId,
      workerAuthUid,
      workerName,
    );
  }

  Stream<QuerySnapshot> getAllComplaints() {
    return _firestoreService.getAllComplaints();
  }

  Stream<QuerySnapshot> getComplaintsByStatus(String status) {
    return _firestoreService.getComplaintsByStatus(status);
  }

  Stream<QuerySnapshot> getWorkerAssignedReports(String workerAuthUid) {
    return _firestoreService.getWorkerAssignedReports(workerAuthUid);
  }
}
