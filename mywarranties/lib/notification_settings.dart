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
  bool _notificationsEnabled = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }
  Future<void> _loadNotificationSettings() async {
    setState(() => _isLoading = true);
    
    try {
      // Check notification permissions first
      _notificationsEnabled = await _notificationService.areNotificationsEnabled();
      
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
                    // Test Notification Section
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
                              'Test Notifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Use these buttons to test if notifications are working properly on your device.',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final success = await NotificationService.sendTestNotification();
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('✅ Test notification sent successfully!'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('❌ Failed to send notification. Check permissions.'),
                                            backgroundColor: Colors.red,
                                            action: SnackBarAction(
                                              label: 'Settings',
                                              textColor: Colors.white,
                                              onPressed: () async {
                                                await _notificationService.openNotificationSettings();
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                      // Refresh permission status
                                      setState(() {
                                        _loadNotificationSettings();
                                      });
                                    },
                                    icon: Icon(Icons.notifications_active),
                                    label: Text('Send Test'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final success = await NotificationService.scheduleTestNotification();
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('⏰ Test notification scheduled for 5 seconds!'),
                                            backgroundColor: Colors.orange,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('❌ Failed to schedule notification. Check permissions.'),
                                            backgroundColor: Colors.red,
                                            action: SnackBarAction(
                                              label: 'Settings',
                                              textColor: Colors.white,
                                              onPressed: () async {
                                                await _notificationService.openNotificationSettings();
                                              },
                                            ),
                                          ),
                                        );
                                      }
                                      // Refresh permission status
                                      setState(() {
                                        _loadNotificationSettings();
                                      });
                                    },
                                    icon: Icon(Icons.schedule),
                                    label: Text('Schedule Test'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 24),
                    // Permission Status Section
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
                              'Notification Permissions',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  _notificationsEnabled ? Icons.check_circle : Icons.error,
                                  color: _notificationsEnabled ? Colors.green : Colors.red,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _notificationsEnabled 
                                        ? 'Notifications are enabled'
                                        : 'Notifications are disabled',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _notificationsEnabled ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!_notificationsEnabled) ...[
                              SizedBox(height: 12),
                              Text(
                                'You need to enable notifications in your device settings for this app to receive warranty reminders.',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                ),
                              ),
                              SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _notificationService.openNotificationSettings();
                                  // Refresh status after user potentially changed settings
                                  await Future.delayed(Duration(seconds: 1));
                                  setState(() {
                                    _loadNotificationSettings();
                                  });
                                },
                                icon: Icon(Icons.settings),
                                label: Text('Open System Settings'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),                    ),
                    SizedBox(height: 24),

                    // Diagnostic Section
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
                              '🔧 Notification Diagnostics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'If notifications are not working properly, try these troubleshooting steps:',
                              style: TextStyle(
                                color: Colors.grey[700],
                              ),
                            ),
                            SizedBox(height: 16),
                            _buildDiagnosticItem(
                              '1. Check App Notifications',
                              'Go to Android Settings > Apps > MyWarranties > Notifications and ensure they are enabled.',
                              Icons.smartphone,
                            ),
                            SizedBox(height: 12),
                            _buildDiagnosticItem(
                              '2. Check Do Not Disturb',
                              'Make sure Do Not Disturb mode is off or MyWarranties is added to exceptions.',
                              Icons.do_not_disturb_off,
                            ),
                            SizedBox(height: 12),
                            _buildDiagnosticItem(
                              '3. Battery Optimization',
                              'Disable battery optimization for MyWarranties in Android Settings > Battery > App optimization.',
                              Icons.battery_full,
                            ),
                            SizedBox(height: 12),
                            _buildDiagnosticItem(
                              '4. Auto-start Permission',
                              'Allow MyWarranties to auto-start in your device\'s security/permission settings.',
                              Icons.power_settings_new,
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await _runDiagnostics();
                                    },
                                    icon: Icon(Icons.play_arrow),
                                    label: Text('Run Diagnostics'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.purple,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await _clearNotificationCache();
                                    },
                                    icon: Icon(Icons.refresh),
                                    label: Text('Reset Service'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
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
            ),    );
  }

  Widget _buildDiagnosticItem(String title, String description, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: Colors.blue,
          size: 20,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _runDiagnostics() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔧 Starting notification diagnostics...');
      
      // Check current permission status
      final permissionStatus = await _notificationService.areNotificationsEnabled();
      print('🔧 Permission status: $permissionStatus');
      
      // Try to send a test notification
      final testResult = await NotificationService.sendTestNotification();
      print('🔧 Test notification result: $testResult');
      
      // Show results to user
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('🔧 Diagnostic Results'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDiagnosticResult('Notification Permissions', permissionStatus),
              SizedBox(height: 8),
              _buildDiagnosticResult('Test Notification', testResult),
              SizedBox(height: 16),
              Text(
                'If any tests failed, please follow the troubleshooting steps above.',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
      
    } catch (e) {
      print('🔧 Diagnostic error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Diagnostic failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDiagnosticResult(String test, bool result) {
    return Row(
      children: [
        Icon(
          result ? Icons.check_circle : Icons.error,
          color: result ? Colors.green : Colors.red,
          size: 16,
        ),
        SizedBox(width: 8),
        Text(
          '$test: ${result ? 'PASS' : 'FAIL'}',
          style: TextStyle(
            color: result ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _clearNotificationCache() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔧 Clearing notification cache...');
      
      // Cancel all notifications
      await _notificationService.cancelAllNotifications();
      
      // Reinitialize the service
      await _notificationService.init();
      
      // Refresh settings
      await _loadNotificationSettings();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Notification service reset successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
    } catch (e) {
      print('🔧 Reset error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Reset failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
}