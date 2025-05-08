import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
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
    // Initialize timezone data
    tz_data.initializeTimeZones();

    // Request permission for notifications
    await _requestPermissions();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Initialize Firebase Messaging
    await _initializeFirebaseMessaging();

    // Schedule warranty expiry checks
    await scheduleWarrantyExpiryChecks();
  }

  Future<void> _requestPermissions() async {
    // Request permission for notifications
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );



    // Request permission for local notifications on Android
    // Note: For newer versions of the plugin, we would use requestPermission()
    // but for compatibility we're using the notification channel approach
    final androidImplementation = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      // Create the notification channel which implicitly requests permission
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          _warrantyChannelId,
          _warrantyChannelName,
          description: _warrantyChannelDescription,
          importance: Importance.high,
        ),
      );
    }
  }

  Future<void> _initializeLocalNotifications() async {
    // Initialize settings for Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize settings for iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Initialize settings for all platforms
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    // Initialize the plugin
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create the notification channel for Android
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _warrantyChannelId,
            _warrantyChannelName,
            description: _warrantyChannelDescription,
            importance: Importance.high,
          ),
        );
  }

  void _onNotificationTapped(NotificationResponse response) {
    // Handle notification tap
    if (response.payload != null) {
      final Map<String, dynamic> data = json.decode(response.payload!);
      
      // You can navigate to a specific screen here based on the payload

      
      // Example: Navigate to product details page
      // Navigator.of(context).push(MaterialPageRoute(
      //   builder: (context) => ProductInfoPage(productId: data['productId']),
      // ));
    }
  }

  Future<void> _initializeFirebaseMessaging() async {
    // Get the token
    String? token = await _firebaseMessaging.getToken();


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



      if (message.notification != null) {

        
        // Show a local notification
        _showLocalNotification(
          title: message.notification!.title ?? 'Warranty Notification',
          body: message.notification!.body ?? '',
          payload: json.encode(message.data),
        );
      }
    });

    // Handle background/terminated messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _warrantyChannelId,
      _warrantyChannelName,
      channelDescription: _warrantyChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      0, // Notification ID
      title,
      body,
      platformDetails,
      payload: payload,
    );
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
      
      final productsCollection = userDoc.collection('products');
      final snapshot = await productsCollection.get();
      final now = DateTime.now();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String? purchaseDate = data['purchaseDate'];
        final String? warrantyPeriod = data['warrantyPeriod'];
        final String? warrantyExtension = data['warrantyExtension'];
        final String productName = data['name'] ?? 'Your product';
        
        if (purchaseDate != null && warrantyPeriod != null) {
          try {
            final expiryDate = calculateExpiryDate(purchaseDate, warrantyPeriod, warrantyExtension);
            
            if (expiryDate != null) {
              final difference = expiryDate.difference(now).inDays;
              
              // Schedule notifications based on the difference and user preferences
              if (difference <= 30 && difference > 7 && notifyThirtyDays) {
                // 30 days before expiry
                scheduleNotification(
                  id: _thirtyDaysNotificationId,
                  title: 'Warranty Expiring Soon',
                  body: '$productName warranty expires in 30 days on ${_formatDate(expiryDate)}',
                  scheduledDate: now,
                  payload: json.encode({'productId': doc.id}),
                );
              } else if (difference <= 7 && difference > 1 && notifySevenDays) {
                // 7 days before expiry
                scheduleNotification(
                  id: _sevenDaysNotificationId,
                  title: 'Warranty Expiring Very Soon',
                  body: '$productName warranty expires in 7 days on ${_formatDate(expiryDate)}',
                  scheduledDate: now,
                  payload: json.encode({'productId': doc.id}),
                );
              } else if (difference == 1 && notifyOneDay) {
                // 24 hours before expiry
                scheduleNotification(
                  id: _oneDayNotificationId,
                  title: 'Warranty Expires Tomorrow',
                  body: '$productName warranty expires tomorrow on ${_formatDate(expiryDate)}',
                  scheduledDate: now,
                  payload: json.encode({'productId': doc.id}),
                );
              } else if (difference == 0 && notifyExpiryDay) {
                // Day of expiry
                scheduleNotification(
                  id: _expiryDayNotificationId,
                  title: 'Warranty Expired Today',
                  body: '$productName warranty has expired today',
                  scheduledDate: now,
                  payload: json.encode({'productId': doc.id}),
                );
              }
            }
          } catch (e) {
            // Error calculating expiry date
          }
        }
      }
    } catch (e) {
      // Error checking warranties
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    final tz.TZDateTime tzScheduledDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _localNotifications.zonedSchedule(
      id,
      title,
      body,
      tzScheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _warrantyChannelId,
          _warrantyChannelName,
          channelDescription: _warrantyChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  DateTime? calculateExpiryDate(String purchaseDate, String warrantyPeriod, String? warrantyExtension) {
    try {
      if (warrantyPeriod.toLowerCase() == 'lifetime') return null;
      
      final purchaseDateTime = DateTime.parse(purchaseDate);
      final warrantyMonths = _parseWarrantyPeriod(warrantyPeriod);
      final extensionMonths = _parseWarrantyPeriod(warrantyExtension ?? '0');
      return purchaseDateTime.add(Duration(days: (warrantyMonths + extensionMonths) * 30));
    } catch (e) {
      // Error calculating expiry date
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// This function must be top-level (not a class method)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // This function will handle background messages
  // Handling a background message
  
  // Initialize Firebase if needed
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.android,
  );
  
  // You can't show UI here, but you can process the message data
  // and schedule a local notification if needed
  if (message.notification != null) {
    // Create a local notification instance
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Initialize settings for Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    
    await flutterLocalNotificationsPlugin.initialize(initSettings);
    
    // Create notification details
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'warranty_expiry_channel',
      'Warranty Expiry Notifications',
      channelDescription: 'Notifications for warranty expiry dates',
      importance: Importance.high,
      priority: Priority.high,
    );
    
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    
    // Show the notification
    await flutterLocalNotificationsPlugin.show(
      0, // Notification ID
      message.notification!.title ?? 'Warranty Notification',
      message.notification!.body ?? '',
      platformDetails,
      payload: json.encode(message.data),
    );
  }
}