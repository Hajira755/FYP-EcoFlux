// lib/services/connectivity_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// True/false stream — collapses the platform's list-of-results API
  /// into a simple "are we online right now" boolean stream.
  Stream<bool> get onStatusChange => _connectivity.onConnectivityChanged
      .map((results) => !results.contains(ConnectivityResult.none));

  Future<bool> hasConnection() async {
    final result = await _connectivity.checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}