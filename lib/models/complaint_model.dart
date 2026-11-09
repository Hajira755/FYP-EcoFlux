import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ComplaintModel {
  final String complaintId;
  final String userId;
  final String description;
  final String category;
  final String priority;
  final GeoPoint? location;
  final String address;
  final String? imageUrl;
  final String status;
  final String? assignedWorkerId;
  final String? assignedWorkerName;
  final Timestamp? timestamp;
  final Timestamp? escalationTime;
  final String? completedImageUrl;
  final Timestamp? lastUpdated;

  ComplaintModel({
    required this.complaintId,
    required this.userId,
    required this.description,
    required this.category,
    required this.priority,
    this.location,
    required this.address,
    this.imageUrl,
    required this.status,
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.timestamp,
    this.escalationTime,
    this.completedImageUrl,
    this.lastUpdated,
  });

  factory ComplaintModel.fromMap(Map<String, dynamic> map, String id) {
    return ComplaintModel(
      complaintId: id,
      userId: map['userId'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? 'Other',
      priority: map['priority'] ?? 'Medium',
      location: map['location'] as GeoPoint?,
      address: map['address'] ?? '',
      imageUrl: map['imageUrl'],
      status: map['status'] ?? 'PENDING',
      assignedWorkerId: map['assignedWorkerId'],
      assignedWorkerName: map['assignedWorkerName'],
      timestamp: map['timestamp'] as Timestamp?,
      escalationTime: map['escalationTime'] as Timestamp?,
      completedImageUrl: map['completedImageUrl'],
      lastUpdated: map['lastUpdated'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'complaintId': complaintId,
      'userId': userId,
      'description': description,
      'category': category,
      'priority': priority,
      'location': location,
      'address': address,
      'imageUrl': imageUrl,
      'status': status,
      'assignedWorkerId': assignedWorkerId,
      'assignedWorkerName': assignedWorkerName,
      'timestamp': timestamp ?? FieldValue.serverTimestamp(),
      'escalationTime': escalationTime,
      'completedImageUrl': completedImageUrl,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Status color helper (UI ke liye useful)
  Color get statusColor {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        return Colors.green;
      case 'ASSIGNED':
      case 'IN_PROGRESS':
        return Colors.blue;
      case 'ESCALATED':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String get statusText => status.toUpperCase();
}