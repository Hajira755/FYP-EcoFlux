import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import '../repositories/user_repository.dart';
import '../models/user_model.dart';

class ProfileViewModel extends ChangeNotifier {
  final UserRepository _userRepository = GetIt.instance<UserRepository>();

  UserModel? _userData;
  bool _isLoading = true;

  UserModel? get userData => _userData;
  bool get isLoading => _isLoading;

  Future<void> loadUserProfile() async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await _userRepository.getUserData(user.uid);
        if (doc.exists) {
          _userData = UserModel.fromMap(doc.data() as Map<String, dynamic>, user.uid);
        }
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

}