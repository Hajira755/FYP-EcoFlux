// lib/viewmodels/auth_viewmodel.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import '../repositories/auth_repository.dart';
import '../services/notification_service.dart';
import '../models/user_model.dart';
import '../core/services/navigation_service.dart';
import '../core/services/snackbar_service.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository = GetIt.instance<AuthRepository>();
  final NavigationService _navService = GetIt.instance<NavigationService>();
  final SnackbarService _snackbarService = GetIt.instance<SnackbarService>();

  bool       _isLoading    = false;
  String?    _errorMessage;
  UserModel? _currentUser;

  bool       get isLoading    => _isLoading;
  String?    get errorMessage => _errorMessage;
  UserModel? get currentUser  => _currentUser;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> login({
    required String      email,
    required String      password,
    required String      selectedRole,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.login(email, password, selectedRole);

      if (user != null) {
        _currentUser = user;

        // Save FCM token for this user/worker so they receive push notifications
        await NotificationService().saveToken(
          userId: user.uid,
          role:   user.role,
        );

        _navigateByRole(user.role, user.name);
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _handleFirebaseError(e.code);
    } catch (e) {
      _errorMessage = 'Something went wrong. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Signup ────────────────────────────────────────────────────────────────
  Future<void> signup({
    required String       name,
    required String       email,
    required String       password,
    required String       role,
    String?               phone,
    String?               area,
    String?               cnic,
  }) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.signup(
        name:     name,
        email:    email,
        password: password,
        role:     role,
        phone:    phone,
        area:     area,
        cnic:     cnic,
      );

      if (user != null) {
        _currentUser = user;

        // Save FCM token after successful signup
        await NotificationService().saveToken(
          userId: user.uid,
          role:   user.role,
        );

        // Admin accounts are created by the system — not via signup
        // So only citizen and worker navigate after signup
        if (role.toLowerCase() == 'citizen' ||
            role.toLowerCase() == 'worker') {
          _navigateByRole(role.toLowerCase(), name);
        }
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _handleFirebaseError(e.code);
    } catch (e) {
      _errorMessage = 'Signup failed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Forgot password ───────────────────────────────────────────────────────
  Future<void> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authRepository.sendPasswordResetEmail(email);

      _snackbarService.showSnackbar('Password reset link sent! Check your email.');
      Future.delayed(const Duration(seconds: 2), () {
        _navService.goBack();
      });
    } on FirebaseAuthException catch (e) {
      _errorMessage = _handleFirebaseError(e.code);
    } catch (e) {
      _errorMessage = 'Failed to send reset email. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    await _authRepository.signOut();
    _currentUser = null;
    notifyListeners();

    _navService.navigateToReplacement('/login_screen');
  }

  // ── Internal helpers ──────────────────────────────────────────────────────
  void _navigateByRole(String role, String name) {
    switch (role) {
      case 'citizen':
        _navService.navigateToReplacement(
          '/citizen_dashboard',
          arguments: name,
        );
        break;
      case 'worker':
        _navService.navigateToReplacement(
          '/worker_dashboard',
          arguments: name,
        );
        break;
      case 'admin':
        _navService.navigateToReplacement(
          '/admin_dashboard',
          arguments: name,
        );
        break;
    }
  }

  String _handleFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email format.';
      case 'invalid-credential':
        return 'Invalid credentials. Check your email and password.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}