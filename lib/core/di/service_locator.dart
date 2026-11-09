import 'package:get_it/get_it.dart';
import '../services/navigation_service.dart';
import '../services/snackbar_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../../services/notification_service.dart';
import '../../services/escalation_service.dart';
import '../../services/location_service.dart';
import '../../services/local_report_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/sync_service.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/report_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/feedback_repository.dart';

final GetIt locator = GetIt.instance;

void setupLocator() {
  // Core Services
  locator.registerLazySingleton(() => NavigationService());
  locator.registerLazySingleton(() => SnackbarService());

  // App Services
  locator.registerLazySingleton(() => AuthService());
  locator.registerLazySingleton(() => FirestoreService());
  locator.registerLazySingleton(() => StorageService());
  locator.registerLazySingleton(() => NotificationService());
  locator.registerLazySingleton(() => EscalationService());
  locator.registerLazySingleton(() => LocationService());

  // Offline-first reporting services
  locator.registerLazySingleton(() => LocalReportService());
  locator.registerLazySingleton(() => ConnectivityService());

  // Repositories
  locator.registerLazySingleton(() => AuthRepository(locator<AuthService>()));
  locator.registerLazySingleton(() => ReportRepository(locator<FirestoreService>()));
  locator.registerLazySingleton(() => UserRepository(locator<FirestoreService>()));
  locator.registerLazySingleton(() => FeedbackRepository(locator<FirestoreService>()));

  // Sync engine — depends on the repository + services above
  locator.registerLazySingleton(() => SyncService(
    reportRepository:    locator<ReportRepository>(),
    storageService:       locator<StorageService>(),
    localReportService:   locator<LocalReportService>(),
    connectivityService:  locator<ConnectivityService>(),
    userRepository:       locator<UserRepository>(),
  ));
}