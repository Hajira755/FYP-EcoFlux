import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> login(String email, String password, String selectedRole) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;
      final docSnap = await _firestore.collection('users').doc(uid).get();

      String name = "User";
      String role = selectedRole.toLowerCase();

      if (!docSnap.exists) {
        if (role == 'admin') {
          throw Exception('Unauthorized role assignment. Admin accounts must be pre-provisioned.');
        }
        name = email.split('@')[0];
        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'name': name,
          'email': email,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        final data = docSnap.data()!;
        name = data['name'] ?? name;
        role = (data['role'] ?? role).toString().toLowerCase();
      }


      return UserModel(
        uid: uid,
        name: name,
        email: email,
        role: role,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> signup({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
    String? area,
    String? cnic,
  }) async {
    try {
      if (role.toLowerCase() == 'admin') {
        throw Exception('Unauthorized role assignment.');
      }
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final userData = {
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone?.trim(),
        'role': role.toLowerCase(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (role.toLowerCase() == 'worker') {
        userData['cnic'] = cnic?.trim();
        userData['workingArea'] = area?.trim();
      } else if (role.toLowerCase() == 'citizen') {
        userData['residentialArea'] = area?.trim();
      }

      await _firestore.collection('users').doc(credential.user!.uid).set(userData);

      return UserModel(
        uid: credential.user!.uid,
        name: name,
        email: email,
        role: role.toLowerCase(),
        phone: phone,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  User? get currentUser => _auth.currentUser;
}