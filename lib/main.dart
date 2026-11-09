// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/firebase_options.dart';
import 'core/navigation/app_routes.dart';
import 'core/themes/app_theme.dart';
import 'core/di/service_locator.dart';
import 'core/services/navigation_service.dart';
import 'core/services/snackbar_service.dart';
import 'services/notification_service.dart';
import 'services/local_report_service.dart';
import 'services/sync_service.dart';
import 'models/pending_report_model.dart';

// ViewModels
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/complaint_viewmodel.dart';
import 'viewmodels/profile_viewmodel.dart';
import 'viewmodels/feedback_viewmodel.dart';
import 'viewmodels/citizen_dashboard_viewmodel.dart';
import 'viewmodels/admin_dashboard_viewmodel.dart';
import 'viewmodels/worker_dashboard_viewmodel.dart';
import 'viewmodels/sync_viewmodel.dart';
import 'viewmodels/notification_viewmodel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ── Offline storage (Hive) ──────────────────────────────────────────────
  await Hive.initFlutter();
  Hive.registerAdapter(PendingReportModelAdapter());
  await LocalReportService.openBox();

  setupLocator();

  // Start the offline-sync engine (connectivity listener + retry timer +
  // uploads any backlog left over from a previous session).
  locator<SyncService>().start();

  // Initialize push notifications
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
        ChangeNotifierProvider(create: (_) => ComplaintViewModel()),
        ChangeNotifierProvider(create: (_) => ProfileViewModel()),
        ChangeNotifierProvider(create: (_) => FeedbackViewModel()),
        ChangeNotifierProvider(create: (_) => CitizenDashboardViewModel()),
        ChangeNotifierProvider(create: (_) => AdminDashboardViewModel()),
        ChangeNotifierProvider(create: (_) => WorkerDashboardViewModel()),
        ChangeNotifierProvider(create: (_) => SyncViewModel()),
        ChangeNotifierProvider(create: (_) => NotificationViewModel()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'EcoFlux',
        theme: AppTheme.lightTheme,
        navigatorKey: locator<NavigationService>().navigatorKey,
        scaffoldMessengerKey: locator<SnackbarService>().scaffoldMessengerKey,
        initialRoute: AppRoutes.splash,
        routes: AppRoutes.routes,
      ),
    );
  }
}