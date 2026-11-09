import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // 'citizen', 'worker', 'admin'
  final String? phone;
  final String? residentialArea;
  final String? workingArea;
  final String? cnic;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.residentialArea,
    this.workingArea,
    this.cnic,
    this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: (map['role'] ?? 'citizen').toString().toLowerCase(),
      phone: map['phone'],
      residentialArea: map['residentialArea'],
      workingArea: map['workingArea'],
      cnic: map['cnic'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}