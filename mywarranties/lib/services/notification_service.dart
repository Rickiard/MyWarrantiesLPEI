import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Channel IDs
  static const String _warrantyChannelId = 'warranty_expiry_channel';
  static const String _warrantyChannelName = 'Warranty Expiry Notifications';
  static const String _warrantyChannelDescription = 'Notifications for warranty expiry dates';

  // Notification IDs
  static const int _thirtyDaysNotificationId = 1;
  static const int _sevenDaysNotificationId = 2;
  static const int _oneDayNotificationId = 3;
  static const int _expiryDayNotificationId = 4;

  Future<void> init() async {
    await AwesomeNotifications().initialize(
      '@mipmap/ic_launcher',
      [
        NotificationChannel(
          channelKey: 'warranty_reminders',
          channelName: 'Warranty Reminders',
          channelDescription: 'Notifications for warranty expiration reminders',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          enableVibration: true,
          enableLights: true,
        ),
      ],
      debug: true,
    );

    // Request notification permissions
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });

    // Listen to notification events
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: _onNotificationTapped,
      onNotificationCreatedMethod: _onNotificationCreated,
      onNotificationDisplayedMethod: _onNotificationDisplayed,
      onDismissActionReceivedMethod: _onNotificationDismissed,
    );

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();
  }

  Future<void> _onNotificationCreated(ReceivedNotification receivedNotification) async {
    // Handle notification creation
  }

  Future<void> _onNotificationDisplayed(ReceivedNotification receivedNotification) async {
    // Handle notification display
  }

  Future<void> _onNotificationDismissed(ReceivedAction receivedAction) async {
    // Handle notification dismissal
  }

  Future<void> _onNotificationTapped(ReceivedAction receivedAction) async {
    // Handle notification tap
    debugPrint('Notification tapped: ${receivedAction.payload}');
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    DateTime? scheduledDate,
  }) async {
    if (scheduledDate != null) {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'warranty_reminders',
          title: title,
          body: body,
          payload: {'data': payload ?? ''},
          notificationLayout: NotificationLayout.Default,
        ),
        schedule: NotificationCalendar.fromDate(date: scheduledDate),
      );
    } else {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: id,
          channelKey: 'warranty_reminders',
          title: title,
          body: body,
          payload: {'data': payload ?? ''},
          notificationLayout: NotificationLayout.Default,
        ),
      );
    }
  }

  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  Future<void> scheduleWarrantyReminder({
    required int id,
    required String title,
    required String body,
    required DateTime expirationDate,
    String? payload,
  }) async {
    // Schedule notification 7 days before expiration
    final reminderDate = expirationDate.subtract(const Duration(days: 7));
    
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'warranty_reminders',
        title: title,
        body: body,
        payload: {'data': payload ?? ''},
        notificationLayout: NotificationLayout.Default,
      ),
      schedule: NotificationCalendar.fromDate(date: reminderDate),
    );
  }

  Future<void> _requestPermissions() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print('User granted permission: ${settings.authorizationStatus}');
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Get the token
    String? token = await _firebaseMessaging.getToken();
    print('FCM Token: $token');

    // Save the token to Firestore
    if (token != null && _auth.currentUser != null) {
      await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .update({'fcmToken': token});
    }

    // Handle token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({'fcmToken': newToken});
      }
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        
        // Show a local notification
        showNotification(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          title: message.notification!.title ?? 'Warranty Notification',
          body: message.notification!.body ?? '',
          payload: json.encode(message.data),
        );
      }
    });

    // Handle background/terminated messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> scheduleWarrantyExpiryChecks() async {
    // Check for warranties expiring soon
    await checkWarrantiesExpiringSoon();
    
    // Schedule the next check for tomorrow
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0); // 9:00 AM tomorrow
    
    // Save the next scheduled check time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nextWarrantyCheck', tomorrow.toIso8601String());
  }

  Future<void> checkWarrantiesExpiringSoon() async {
    if (_auth.currentUser == null) return;

    try {
      // Load user notification preferences
      final prefs = await SharedPreferences.getInstance();
      final notifyThirtyDays = prefs.getBool('notify_thirty_days') ?? true;
      final notifySevenDays = prefs.getBool('notify_seven_days') ?? true;
      final notifyOneDay = prefs.getBool('notify_one_day') ?? true;
      final notifyExpiryDay = prefs.getBool('notify_expiry_day') ?? true;
      
      // Get user's notification settings from Firestore if available
      final userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid);
      final userSnapshot = await userDoc.get();
      
      // If user has notification settings in Firestore, use those instead
      if (userSnapshot.exists && userSnapshot.data()!.containsKey('notificationSettings')) {
        final settings = userSnapshot.data()!['notificationSettings'];
        final notifyThirtyDaysFirestore = settings['thirtyDays'];
        final notifySevenDaysFirestore = settings['sevenDays'];
        final notifyOneDayFirestore = settings['oneDay'];
        final notifyExpiryDayFirestore = settings['expiryDay'];
        
        // Use Firestore settings if they exist, otherwise use SharedPreferences
        if (notifyThirtyDaysFirestore != null) {
          await prefs.setBool('notify_thirty_days', notifyThirtyDaysFirestore);
        }
        if (notifySevenDaysFirestore != null) {
          await prefs.setBool('notify_seven_days', notifySevenDaysFirestore);
        }
        if (notifyOneDayFirestore != null) {
          await prefs.setBool('notify_one_day', notifyOneDayFirestore);
        }
        if (notifyExpiryDayFirestore != null) {
          await prefs.setBool('notify_expiry_day', notifyExpiryDayFirestore);
        }
      }
      
      // Get all warranties
      final warrantiesSnapshot = await _firestore
          .collection('users')
          .doc(_auth.currentUser!.uid)
          .collection('warranties')
          .get();
      
      final now = DateTime.now();
      
      for (var doc in warrantiesSnapshot.docs) {
        final data = doc.data();
        final expiryDate = (data['expiryDate'] as Timestamp).toDate();
        final daysUntilExpiry = expiryDate.difference(now).inDays;
        
        // Check if we should notify based on days until expiry
        if (daysUntilExpiry == 30 && notifyThirtyDays) {
          await showNotification(
            id: _thirtyDaysNotificationId,
            title: 'Warranty Expiring Soon',
            body: '${data['productName']} warranty expires in 30 days',
            payload: json.encode({'warrantyId': doc.id}),
          );
        } else if (daysUntilExpiry == 7 && notifySevenDays) {
          await showNotification(
            id: _sevenDaysNotificationId,
            title: 'Warranty Expiring Soon',
            body: '${data['productName']} warranty expires in 7 days',
            payload: json.encode({'warrantyId': doc.id}),
          );
        } else if (daysUntilExpiry == 1 && notifyOneDay) {
          await showNotification(
            id: _oneDayNotificationId,
            title: 'Warranty Expiring Tomorrow',
            body: '${data['productName']} warranty expires tomorrow',
            payload: json.encode({'warrantyId': doc.id}),
          );
        } else if (daysUntilExpiry == 0 && notifyExpiryDay) {
          await showNotification(
            id: _expiryDayNotificationId,
            title: 'Warranty Expired',
            body: '${data['productName']} warranty has expired today',
            payload: json.encode({'warrantyId': doc.id}),
          );
        }
      }
    } catch (e) {
      print('Error checking warranties: $e');
    }
  }

  DateTime? calculateExpiryDate(String purchaseDate, String warrantyPeriod, String? warrantyExtension) {
    try {
      if (warrantyPeriod.toLowerCase() == 'lifetime') return null;
      
      final purchaseDateTime = DateTime.parse(purchaseDate);
      final warrantyMonths = _parseWarrantyPeriod(warrantyPeriod);
      final extensionMonths = _parseWarrantyPeriod(warrantyExtension ?? '0');
      return purchaseDateTime.add(Duration(days: (warrantyMonths + extensionMonths) * 30));
    } catch (e) {
      print('Error calculating expiry date: $e');
      return null;
    }
  }

  int _parseWarrantyPeriod(String warranty) {
    if (warranty.toLowerCase() == 'lifetime') return 0;
    final parts = warranty.toLowerCase().split(' ');
    if (parts.isEmpty) return 0;
    
    final value = int.tryParse(parts[0]) ?? 0;
    if (warranty.contains('day')) {
      return value ~/ 30; // Convert days to months
    } else if (warranty.contains('month')) {
      return value;
    } else if (warranty.contains('year')) {
      return value * 12;
    }
    return 0;
  }
}

// This needs to be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('Handling a background message: ${message.messageId}');
}