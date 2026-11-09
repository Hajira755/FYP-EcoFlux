import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final AuthService _authService;

  AuthRepository(this._authService);

  Future<UserModel?> login(String email, String password, String selectedRole) {
    return _authService.login(email, password, selectedRole);
  }

  Future<UserModel?> signup({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? area,
    String? cnic,
  }) {
    return _authService.signup(
      name: name,
      email: email,
      password: password,
      role: role,
      phone: phone,
      area: area,
      cnic: cnic,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _authService.sendPasswordResetEmail(email);
  }

  Future<void> signOut() {
    return _authService.signOut();
  }

  User? get currentUser => _authService.currentUser;
  
  Stream<User?> get authStateChanges => _authService.authStateChanges;
}
