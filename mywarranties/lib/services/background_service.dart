import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

// Make the constants accessible to all functions
const String warrantyCheckTaskName = 'warrantyCheck';
const String productUpdatedTaskName = 'productUpdated';

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
  
  // New method to notify about product changes
  static Future<void> notifyProductChanged({
    required String productId, 
    required Map<String, dynamic> productData,
    required bool isNewProduct
  }) async {
    final service = FlutterBackgroundService();
    
    // Invoke a task to check this specific product for notifications
    service.invoke(productUpdatedTaskName, {
      'productId': productId,
      'productData': productData,
      'isNewProduct': isNewProduct
    });
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
        
        // Schedule the next check for tomorrow
        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0); // 9:00 AM tomorrow
        
        // Calculate delay until next check
        final delay = tomorrow.difference(now).inMilliseconds;
        if (delay > 0) {
          // Schedule the next check
          Future.delayed(Duration(milliseconds: delay), () {
            service.invoke(warrantyCheckTaskName);
          });
        }
      } catch (e) {
        print('Background task error: $e');
      }
    });
    
    // Add handler for product update notifications
    service.on(productUpdatedTaskName).listen((event) async {
      try {
        if (event == null) return;
        
        final productId = event['productId'];
        final productData = event['productData'];
        final isNewProduct = event['isNewProduct'] ?? false;
        
        if (productId == null || productData == null) return;
        
        final notificationService = NotificationService();
        await notificationService.checkSingleProductWarranty(
          productId: productId, 
          productData: Map<String, dynamic>.from(productData),
          isNewProduct: isNewProduct
        );
      } catch (e) {
        print('Product update notification error: $e');
      }
    });
  }
}