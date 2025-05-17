import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// Make the constant accessible to all functions
const String warrantyCheckTaskName = 'warrantyCheck';

class BackgroundService {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    // Configure the background service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'warranty_check_service',
        initialNotificationTitle: 'Warranty Check Service',
        initialNotificationContent: 'Checking warranties in background',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    
    // Schedule daily warranty check
    await scheduleDailyWarrantyCheck();
  }
  
  static Future<void> scheduleDailyWarrantyCheck() async {
    final service = FlutterBackgroundService();
    
    // Schedule periodic task
    service.invoke(warrantyCheckTaskName);
    
    // Save the last scheduled time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastWarrantyCheckScheduled', DateTime.now().toIso8601String());
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on(warrantyCheckTaskName).listen((event) async {
      try {
        final notificationService = NotificationService();
        await notificationService.checkWarrantiesExpiringSoon();
        
        // Update the last check time
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastWarrantyCheck', DateTime.now().toIso8601String());
      } catch (e) {
        print('Background task error: $e');
      }
    });
  }
}