// lib/core/navigation/app_routes.dart

import 'package:flutter/material.dart';

// Auth
import '../../views/auth/splash_screen.dart';
import '../../views/auth/login_screen.dart';
import '../../views/auth/signup_screen.dart';
import '../../views/auth/forgot_password_screen.dart';

// Dashboards
import '../../views/dashboard/citizen_dashboard_screen.dart';
import '../../views/dashboard/worker_dashboard_screen.dart';
import '../../views/dashboard/admin_dashboard_screen.dart';

// Complaint / Report
import '../../views/complaint/new_report_screen.dart';
import '../../views/complaint/track_complaint_screen.dart';
import '../../views/complaint/report_detail_screen.dart';
import '../../views/complaint/offline_queue_screen.dart';

// Other
import '../../views/profile/profile_screen.dart';
import '../../views/feedback/feedback_screen.dart';
import '../../views/notifications/notifications_screen.dart';

// Model
import '../../models/complaint_model.dart';

class AppRoutes {
  // ── Route name constants ───────────────────────────────────────────────────
  static const String splash           = '/';
  static const String login            = '/login_screen';
  static const String signup           = '/signup_screen';
  static const String forgotPassword   = '/forgot_password';

  static const String citizenDashboard = '/citizen_dashboard';
  static const String workerDashboard  = '/worker_dashboard';
  static const String adminDashboard   = '/admin_dashboard';

  static const String newReport        = '/new_report';
  static const String trackComplaint   = '/track_complaint';
  static const String reportDetail     = '/report_detail';
  static const String offlineQueue     = '/offline_queue';
  static const String profile          = '/profile';
  static const String feedback         = '/feedback';
  static const String notifications    = '/notifications';

  // ── Route map ─────────────────────────────────────────────────────────────
  static Map<String, WidgetBuilder> get routes => {

    // ── Auth ──────────────────────────────────────────────────────────────────
    splash:         (_) => const SplashScreen(),
    login:          (_) => const LoginScreen(),
    signup:         (_) => const SignupScreen(),
    forgotPassword: (_) => const ForgotPasswordScreen(),

    // ── Dashboards ────────────────────────────────────────────────────────────
    citizenDashboard: (context) {
      final userName =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'User';
      return CitizenDashboardScreen(userName: userName);
    },

    workerDashboard: (context) {
      final workerName =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'Worker';
      return WorkerDashboardScreen(workerName: workerName);
    },

    adminDashboard: (context) {
      final userName =
          ModalRoute.of(context)?.settings.arguments as String? ?? 'Admin';
      return AdminDashboardScreen(userName: userName);
    },

    // ── Reports ───────────────────────────────────────────────────────────────

    // No arguments needed
    newReport: (_) => const NewReportScreen(),

    // Optional String complaintId — null means show full list
    trackComplaint: (context) {
      final complaintId =
      ModalRoute.of(context)?.settings.arguments as String?;
      return TrackComplaintScreen(complaintId: complaintId);
    },

    // Requires a ComplaintModel passed as arguments:
    // Navigator.pushNamed(context, AppRoutes.reportDetail, arguments: report)
    reportDetail: (context) {
      final report =
      ModalRoute.of(context)?.settings.arguments as ComplaintModel?;
      if (report == null) {
        return const Scaffold(
          body: Center(child: Text('Report not found.')),
        );
      }
      return const ReportDetailScreen();
    },

    // Offline sync queue — no arguments needed
    offlineQueue: (_) => const OfflineQueueScreen(),

    // ── Other ─────────────────────────────────────────────────────────────────
    profile:      (_) => const ProfileScreen(),
    feedback:     (_) => const FeedbackScreen(),
    notifications: (_) => const NotificationsScreen(),
  };
}