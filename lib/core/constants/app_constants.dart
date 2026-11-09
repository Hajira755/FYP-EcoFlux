import 'package:flutter/material.dart';

class AppConstants {
  // App Info
  static const String appName = 'EcoFlux';
  static const String appTagline = 'Waste Management & Reporting System';

  // Colors (Extra reusable colors)
  static const Color primaryGreen = Color(0xFF1B5E20);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color darkGreen = Color(0xFF0F4C3A);
  static const Color accentBlue = Color(0xFF2196F3);

  // Gradient Colors (commonly used in your screens)
  static const List<Color> lightGradient = [
    Color(0xFFE8F5E9),
    Color(0xFFE3F2FD),
    Color(0xFFF1F8E9),
  ];

  static const List<Color> splashGradient = [
    Color(0xFF90CAF9),
    Color(0xFFE8F5E9),
  ];

  // Default Values
  static const String defaultRole = 'citizen';
  static const int passwordMinLength = 6;

  // Civic Points (gamification) — awarded automatically by the app.
  // Submission points fire the moment a report actually reaches Firestore
  // (SyncService, right after a successful upload — works for both the
  // instant-online path and the offline-queued-then-synced path).
  // Resolution points fire once, the moment a report first flips to
  // COMPLETED (admin or worker dashboard).
  static const int pointsForReportSubmission = 10;
  static const int pointsForReportResolution = 20;



  // Routes (for easy access)
  static const String splashRoute = '/';
  static const String loginRoute = '/login_screen';
  static const String signupRoute = '/signup_screen';
  static const String forgotPasswordRoute = '/forgot_password';
  static const String citizenDashboardRoute = '/citizen_dashboard';
  static const String workerDashboardRoute = '/worker_dashboard';
  static const String adminDashboardRoute = '/admin_dashboard';
  static const String newReportRoute = '/new_report';
  static const String trackComplaintRoute = '/track_complaint';
  static const String profileRoute = '/profile';
  static const String feedbackRoute = '/feedback';
  static const String reportDetailRoute  = '/report_detail';
}