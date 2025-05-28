import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({Key? key}) : super(key: key);

  @override
  _NotificationSettingsPageState createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _isLoading = true;
  bool _thirtyDaysNotification = true;
  bool _sevenDaysNotification = true;
  bool _oneDayNotification = true;
  bool _expiryDayNotification = true;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    setState(() => _isLoading = true);
    
    try {
      if (_auth.currentUser != null) {
        // Try to load from Firestore first
        final userDoc = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .get();
        
        if (userDoc.exists && userDoc.data()!.containsKey('notificationSettings')) {
          final settings = userDoc.data()!['notificationSettings'];
          setState(() {
            _thirtyDaysNotification = settings['thirtyDays'] ?? true;
            _sevenDaysNotification = settings['sevenDays'] ?? true;
            _oneDayNotification = settings['oneDay'] ?? true;
            _expiryDayNotification = settings['expiryDay'] ?? true;
          });
        } else {
          // If not in Firestore, try to load from SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          setState(() {
            _thirtyDaysNotification = prefs.getBool('notify_thirty_days') ?? true;
            _sevenDaysNotification = prefs.getBool('notify_seven_days') ?? true;
            _oneDayNotification = prefs.getBool('notify_one_day') ?? true;
            _expiryDayNotification = prefs.getBool('notify_expiry_day') ?? true;
          });
          
          // Save to Firestore for future use
          await _saveNotificationSettings();
        }
      } else {
        // If not logged in, just load from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        setState(() {
          _thirtyDaysNotification = prefs.getBool('notify_thirty_days') ?? true;
          _sevenDaysNotification = prefs.getBool('notify_seven_days') ?? true;
          _oneDayNotification = prefs.getBool('notify_one_day') ?? true;
          _expiryDayNotification = prefs.getBool('notify_expiry_day') ?? true;
        });
      }
    } catch (e) {
      print('Error loading notification settings: $e');
      // Use defaults if there's an error
      setState(() {
        _thirtyDaysNotification = true;
        _sevenDaysNotification = true;
        _oneDayNotification = true;
        _expiryDayNotification = true;
      });
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveNotificationSettings() async {
    try {
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notify_thirty_days', _thirtyDaysNotification);
      await prefs.setBool('notify_seven_days', _sevenDaysNotification);
      await prefs.setBool('notify_one_day', _oneDayNotification);
      await prefs.setBool('notify_expiry_day', _expiryDayNotification);
      
      // Save to Firestore if logged in
      if (_auth.currentUser != null) {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .update({
          'notificationSettings': {
            'thirtyDays': _thirtyDaysNotification,
            'sevenDays': _sevenDaysNotification,
            'oneDay': _oneDayNotification,
            'expiryDay': _expiryDayNotification,
          }
        });
      }
      
      // Refresh notification service with new settings
      final notificationService = NotificationService();
      await notificationService.checkWarrantiesExpiringSoon();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification settings saved')),
      );
    } catch (e) {
      print('Error saving notification settings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving notification settings')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAFE1F0),
      appBar: AppBar(
        title: Text('Notification Settings'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Warranty Expiry Notifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Choose when you want to be notified about your warranties expiring:',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 16),
                            SwitchListTile(
                              title: Text('30 days before expiry'),
                              subtitle: Text('Get notified a month before warranty expires'),
                              value: _thirtyDaysNotification,
                              onChanged: (value) {
                                setState(() => _thirtyDaysNotification = value);
                              },
                              activeColor: Colors.blue,
                            ),
                            Divider(),
                            SwitchListTile(
                              title: Text('7 days before expiry'),
                              subtitle: Text('Get notified a week before warranty expires'),
                              value: _sevenDaysNotification,
                              onChanged: (value) {
                                setState(() => _sevenDaysNotification = value);
                              },
                              activeColor: Colors.blue,
                            ),
                            Divider(),
                            SwitchListTile(
                              title: Text('24 hours before expiry'),
                              subtitle: Text('Get notified a day before warranty expires'),
                              value: _oneDayNotification,
                              onChanged: (value) {
                                setState(() => _oneDayNotification = value);
                              },
                              activeColor: Colors.blue,
                            ),
                            Divider(),
                            SwitchListTile(
                              title: Text('On expiry day'),
                              subtitle: Text('Get notified when warranty expires'),
                              value: _expiryDayNotification,
                              onChanged: (value) {
                                setState(() => _expiryDayNotification = value);
                              },
                              activeColor: Colors.blue,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'About Notifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'MyWarranties will check your products daily and send you notifications based on your preferences above.',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Make sure notifications are enabled for this app in your device settings.',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    Center(
                      child: ElevatedButton(
                        onPressed: _saveNotificationSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Save Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}