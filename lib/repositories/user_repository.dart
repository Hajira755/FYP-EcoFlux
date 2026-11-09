import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestoreService;

  UserRepository(this._firestoreService);

  Future<DocumentSnapshot> getUserData(String uid) {
    return _firestoreService.getUserData(uid);
  }

  Stream<DocumentSnapshot> getUserStream(String uid) {
    return _firestoreService.getUserStream(uid);
  }

  Future<void> updateUserData(String uid, Map<String, dynamic> data) {
    return _firestoreService.updateUserData(uid, data);
  }

  /// Awards/adjusts civic points and complaint counters. See
  /// FirestoreService.incrementUserStats for the underlying atomic logic.
  Future<void> incrementUserStats(
      String uid, {
        int civicPointsDelta = 0,
        int totalComplaintsDelta = 0,
        int resolvedComplaintsDelta = 0,
        int pendingComplaintsDelta = 0,
      }) {
    return _firestoreService.incrementUserStats(
      uid,
      civicPointsDelta: civicPointsDelta,
      totalComplaintsDelta: totalComplaintsDelta,
      resolvedComplaintsDelta: resolvedComplaintsDelta,
      pendingComplaintsDelta: pendingComplaintsDelta,
    );
  }
}