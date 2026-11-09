// ignore: unused_import
import 'package:cloud_firestore/cloud_firestore.dart';

class WorkerModel {
  final String workerId;    // Firestore document ID
  final String authUid;     // Firebase Auth UID — used for task-assignment queries
  final String name;
  final String phone;
  final String area;
  final bool isActive;
  final int completedTasks;

  WorkerModel({
    required this.workerId,
    required this.authUid,
    required this.name,
    required this.phone,
    required this.area,
    this.isActive = true,
    this.completedTasks = 0,
  });

  factory WorkerModel.fromMap(Map<String, dynamic> map, String id) {

    final resolvedAuthUid =
    (map['authUid'] as String?)?.isNotEmpty == true
        ? map['authUid'] as String
        : (map['workerId'] as String?)?.isNotEmpty == true
        ? map['workerId'] as String
        : id;

    return WorkerModel(
      workerId: id,
      authUid: resolvedAuthUid,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      area: map['area'] ?? map['workingArea'] ?? '',
      isActive: map['isActive'] ?? true,
      completedTasks: map['completedTasks'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authUid': authUid,
      'name': name,
      'phone': phone,
      'area': area,
      'isActive': isActive,
      'completedTasks': completedTasks,
    };
  }
}