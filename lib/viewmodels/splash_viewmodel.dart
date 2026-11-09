import 'package:flutter/material.dart';

class SplashViewModel extends ChangeNotifier {
  
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  void initialize() {
    _isInitialized = true;
    notifyListeners();
  }
}