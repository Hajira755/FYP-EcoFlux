// lib/viewmodels/citizen_dashboard_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../repositories/user_repository.dart';

class CitizenDashboardViewModel extends ChangeNotifier {
  final UserRepository _userRepository = GetIt.instance<UserRepository>();

  bool   _isLoading   = false;
  int    _civicPoints = 0;

  // These are kept for any admin/static use — live counts come from
  // ComplaintViewModel in the dashboard itself
  int _totalComplaints    = 0;
  int _resolvedComplaints = 0;
  int _pendingComplaints  = 0;

  bool get isLoading           => _isLoading;
  int  get civicPoints         => _civicPoints;
  int  get totalComplaints     => _totalComplaints;
  int  get resolvedComplaints  => _resolvedComplaints;
  int  get pendingComplaints   => _pendingComplaints;

  /// Returns [Future<void>] so callers can safely `await` it.
  Future<void> loadDashboardStats(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final userDoc = await _userRepository.getUserData(userId);
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _civicPoints         = (data['civicPoints']         as num?)?.toInt() ?? 0;
        _totalComplaints     = (data['totalComplaints']     as num?)?.toInt() ?? 0;
        _resolvedComplaints  = (data['resolvedComplaints']  as num?)?.toInt() ?? 0;
        _pendingComplaints   = (data['pendingComplaints']   as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint('CitizenDashboardViewModel error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}