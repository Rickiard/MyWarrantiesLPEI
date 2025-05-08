import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class BackgroundService {
  static const String warrantyCheckTaskName = 'com.mywarranties.checkWarranties';
  
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );
    
    // Schedule daily warranty check
    await scheduleDailyWarrantyCheck();
  }
  
  static Future<void> scheduleDailyWarrantyCheck() async {
    await Workmanager().registerPeriodicTask(
      warrantyCheckTaskName,
      warrantyCheckTaskName,
      frequency: const Duration(days: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: false,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    
    // Save the last scheduled time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastWarrantyCheckScheduled', DateTime.now().toIso8601String());
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == BackgroundService.warrantyCheckTaskName) {
        final notificationService = NotificationService();
        await notificationService.checkWarrantiesExpiringSoon();
        
        // Update the last check time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastWarrantyCheck', DateTime.now().toIso8601String());
      }
      return Future.value(true);
    } catch (e) {
      // Background task error occurred
      return Future.value(false);
    }
  });
}