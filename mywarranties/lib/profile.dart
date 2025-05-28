import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mywarranties/main.dart' as app;
import 'package:mywarranties/list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_settings.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'services/local_file_storage_service.dart';
import 'services/image_copy_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

// Initialize GoogleSignIn
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: '598622253789-1oljk3c82dcqorbofvvb2otn12bkkp9s.apps.googleusercontent.com',
  scopes: [
    'email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ],
);

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  // Load and auto-login to the last active account (called from main.dart on app start)
  static Future<bool> tryAutoLoginToLastAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActiveEmail = prefs.getString('lastActiveEmail');
      final lastActiveUid = prefs.getString('lastActiveUid');
      final lastActiveIsGoogle = prefs.getBool('lastActiveIsGoogle') ?? false;
      
      if (lastActiveEmail == null || lastActiveUid == null) {
        print('No last active account found');
        return false;
      }
      
      print('Attempting auto-login to last active account: $lastActiveEmail');
      
      if (lastActiveIsGoogle) {
        final lastActiveAccessToken = prefs.getString('lastActiveAccessToken');
        final lastActiveIdToken = prefs.getString('lastActiveIdToken');
        
        if (lastActiveAccessToken != null && lastActiveIdToken != null) {
          try {
            final AuthCredential credential = GoogleAuthProvider.credential(
              accessToken: lastActiveAccessToken,
              idToken: lastActiveIdToken,
            );
            await FirebaseAuth.instance.signInWithCredential(credential);
            
            // Update login status
            await prefs.setBool('isLoggedIn', true);
            await prefs.setString('userEmail', lastActiveEmail);
            await prefs.setString('accessToken', lastActiveAccessToken);
            await prefs.setString('idToken', lastActiveIdToken);
            
            print('Auto-login successful for Google account: $lastActiveEmail');
            return true;
          } catch (e) {
            print('Auto-login failed for Google account: $e');
          }
        }
      } else {
        final lastActivePassword = prefs.getString('lastActivePassword');
        
        if (lastActivePassword != null && lastActivePassword.isNotEmpty) {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: lastActiveEmail,
              password: lastActivePassword,
            );
            
            // Update login status
            await prefs.setBool('isLoggedIn', true);
            await prefs.setString('userEmail', lastActiveEmail);
            await prefs.setString('userPassword', lastActivePassword);
            
            print('Auto-login successful for email account: $lastActiveEmail');
            return true;
          } catch (e) {
            print('Auto-login failed for email account: $e');
          }
        }
      }
      
      // Clear invalid last active account data
      await prefs.remove('lastActiveEmail');
      await prefs.remove('lastActiveUid');
      await prefs.remove('lastActiveIsGoogle');
      await prefs.remove('lastActiveAccessToken');
      await prefs.remove('lastActiveIdToken');
      await prefs.remove('lastActivePassword');
      
      return false;
    } catch (e) {
      print('Error during auto-login: $e');
      return false;
    }
  }

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FileStorageService _fileStorage = FileStorageService();  
  final ImageCopyService _imageCopyService = ImageCopyService();
  bool _isLoading = true;
  String _username = '';
  String _email = '';
  List<Map<String, dynamic>> _quickSwitchAccounts = [];
  // Controller for adding new account
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadQuickSwitchAccounts();
  }
  // Load quick switch accounts from persistent storage (SharedPreferences)
  Future<void> _loadQuickSwitchAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final quickSwitchAccountsJson = prefs.getStringList('persistentQuickSwitchAccounts') ?? [];
      
      print('Loading quick switch accounts: ${quickSwitchAccountsJson.length} accounts found');
      
      final List<Map<String, dynamic>> loadedAccounts = [];
      final Set<String> addedEmails = {}; // Track emails to prevent duplicates
        for (String accountJson in quickSwitchAccountsJson) {
        final Map<String, dynamic> account = {};
        final parts = accountJson.split(':::');
        
        // Check if this is in the new format (with isGoogleAccount flag)
        if (parts.length >= 6) {
          final email = parts[0];
          final emailLower = email.toLowerCase();
          
          print('Processing account: $email');
          
          // Skip if we've already added this email (prevent duplicates only)
          if (addedEmails.contains(emailLower)) {
            print('Skipping account $email (duplicate)');
            continue;
          }
          
          account['email'] = email;
          account['uid'] = parts[1];
          account['password'] = parts[2];
          account['isGoogleAccount'] = parts[3] == 'true';
          account['accessToken'] = parts[4];
          account['idToken'] = parts[5];
          
          loadedAccounts.add(account);
          addedEmails.add(emailLower);
          print('Added account: $email to quick switch accounts (${account['isGoogleAccount'] ? "Google" : "Email"})');
        }        // Support for old format
        else if (parts.length >= 3) {
          final email = parts[0];
          final emailLower = email.toLowerCase();
          
          print('Processing account (old format): $email');
          
          // Skip if we've already added this email (prevent duplicates only)
          if (addedEmails.contains(emailLower)) {
            print('Skipping account $email (duplicate)');
            continue;
          }
          
          account['email'] = email;
          account['uid'] = parts[1];
          account['password'] = parts[2];
          account['isGoogleAccount'] = parts[2] == 'google_sign_in';
          
          loadedAccounts.add(account);
          addedEmails.add(emailLower);
          print('Added account: $email to quick switch accounts (old format)');
        }
      }
      
      print('Final quick switch accounts count: ${loadedAccounts.length}');
      
      setState(() {
        _quickSwitchAccounts = loadedAccounts;
      });
    } catch (e) {
      print('Error loading quick switch accounts: $e');
    }
  }
    // Save quick switch accounts to persistent storage (SharedPreferences)
  Future<void> _saveQuickSwitchAccounts() async {
    try {
      print('Saving quick switch accounts...');
      print('Current accounts in memory: ${_quickSwitchAccounts.length}');
      
      final prefs = await SharedPreferences.getInstance();
      final List<String> accountsToSave = [];
      final Set<String> emailsAdded = {}; // Track emails to prevent duplicates
        // Add all quick switch accounts (avoiding duplicates)
      for (var account in _quickSwitchAccounts) {
        final email = account['email'] as String;
        if (!emailsAdded.contains(email.toLowerCase())) {
          final isGoogleAccount = account['isGoogleAccount'] == true;
          final password = account['password'] as String? ?? '';
          final uid = account['uid'] as String? ?? '';
          final accessToken = account['accessToken'] as String? ?? '';
          final idToken = account['idToken'] as String? ?? '';
          
          if (isGoogleAccount) {
            accountsToSave.add('$email:::$uid:::google_sign_in:::true:::$accessToken:::$idToken');
          } else {
            accountsToSave.add('$email:::$uid:::$password:::false::::::');
          }
          
          emailsAdded.add(email.toLowerCase());
          print('Added quick switch account to save list: $email (${isGoogleAccount ? "Google" : "Email"})');
        } else {
          print('Skipping duplicate account: $email');
        }
      }
      
      print('Total accounts to save: ${accountsToSave.length}');
      await prefs.setStringList('persistentQuickSwitchAccounts', accountsToSave);
        // Verify what was saved
      final savedAccounts = prefs.getStringList('persistentQuickSwitchAccounts') ?? [];
      print('Accounts saved to SharedPreferences: ${savedAccounts.length}');
      for (var account in savedAccounts) {
        final parts = account.split(':::');
        if (parts.isNotEmpty) {
          print('Saved account: ${parts[0]} (${parts.length >= 4 && parts[3] == "true" ? "Google" : "Email"})');
        }
      }
    } catch (e) {
      print('Error saving quick switch accounts: $e');
    }
  }  // Clear all quick switch accounts from memory and persistent storage
  Future<void> _clearQuickSwitchAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('persistentQuickSwitchAccounts');
      
      setState(() {
        _quickSwitchAccounts.clear();
      });
      
      print('All quick switch accounts cleared from memory and storage');
    } catch (e) {
      print('Error clearing quick switch accounts: $e');
    }
  }
  Future<void> _loadUserData() async {
    if (_auth.currentUser == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get current user email
      final User? user = _auth.currentUser;
      if (user != null) {
        setState(() {
          _email = user.email ?? 'No email found';
          // Extract username from email (part before @)
          _username = _email.split('@')[0];
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }  Future<void> _logout() async {    // Show custom confirmation dialog for logout
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout? All saved accounts will be removed and you will need to log in again when you return.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Logout'),
          ),
        ],
      ),
    );
    // If user cancelled or closed the dialog, do nothing
    if (confirmLogout != true) return;
    
    // Show loading with useRootNavigator to ensure it can be closed correctly
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Logging out..."),
            ],
          ),
        ),
      ),
    );
    
    try {
      // Clear all quick switch accounts first
      await _clearQuickSwitchAccounts();
      
      // Update user status in Firestore if user is logged in
      if (_auth.currentUser != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final deviceToken = prefs.getString('deviceToken');
          
          // Only clear the session if the device token matches
          if (deviceToken != null) {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(_auth.currentUser!.uid)
                .get();
                
            if (userDoc.exists) {
              final data = userDoc.data();
              if (data?['deviceToken'] == deviceToken) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(_auth.currentUser!.uid)
                    .update({
                  'isLoggedIn': false,
                  'deviceToken': null,
                });
              }
            }
          }
        } catch (e) {
          print('Error updating user login status: $e');
        }
      }
      
      // Sign out from Firebase
      await _auth.signOut();      // Clear SharedPreferences (but preserve persistent quick switch accounts)
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isLoggedIn', false);
      prefs.remove('userEmail');
      prefs.remove('userPassword');
      prefs.remove('accessToken');
      prefs.remove('idToken');
      prefs.remove('deviceToken');
      
      // Clear last active account data
      prefs.remove('lastActiveEmail');
      prefs.remove('lastActiveUid');
      prefs.remove('lastActiveIsGoogle');
      prefs.remove('lastActiveAccessToken');
      prefs.remove('lastActiveIdToken');
      prefs.remove('lastActivePassword');
      
      // Note: persistentQuickSwitchAccounts is preserved for next session
      // Wait a small delay to ensure all operations are completed
      await Future.delayed(Duration(milliseconds: 300));
      
      // Close the loading dialog with rootNavigator
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();      }
      
      // Wait another small delay to ensure UI is stable
      await Future.delayed(Duration(milliseconds: 200));
      
      // Navigate to the welcome screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => app.MyApp()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error during logout: $e');
        // Close the loading dialog if it's open
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }  Widget _buildAccountItem({
    required String email,
    required bool isActive,
    required VoidCallback onSwitch,
    required VoidCallback onRemove,
    bool isGoogleAccount = false,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: isActive
            ? Border.all(color: Colors.blue.withOpacity(0.3), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          isGoogleAccount
            ? Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/Google__G__logo.svg.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              )
            : Icon(
                Icons.account_circle,
                color: isActive ? Colors.blue : Colors.grey,
                size: 28,
              ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        email,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? Colors.black87 : Colors.black54,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (isActive)
                      Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    if (isGoogleAccount)
                      Padding(
                        padding: EdgeInsets.only(left: isActive ? 8.0 : 0),
                        child: Text(
                          'Google Account',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!isActive)
            Row(
              children: [
                TextButton(
                  onPressed: onSwitch,
                  child: Text('Switch', style: TextStyle(color: Colors.blue)),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  onPressed: onRemove,
                ),
              ],
            ),
        ],
      ),
    );
  }
  void _showAddAccountDialog() {
    _emailController.clear();
    _passwordController.clear();
    _isPasswordVisible = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    try {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Center(child: CircularProgressIndicator()),
                      );
                      
                      final currentUserEmail = _auth.currentUser?.email?.toLowerCase() ?? '';
                      
                      // Create a new GoogleSignIn instance for adding accounts
                      final GoogleSignIn newGoogleSignIn = GoogleSignIn();
                      await newGoogleSignIn.signOut(); // Clear any cached sign-in
                      
                      final GoogleSignInAccount? googleUser = await newGoogleSignIn.signIn();
                      if (googleUser != null) {
                        if (googleUser.email.toLowerCase() == currentUserEmail) {
                          if (Navigator.canPop(context)) Navigator.pop(context);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(children: [Icon(Icons.info_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('You are already authenticated with this Google account.'))]),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        
                        // Check if account is already saved
                        if (_quickSwitchAccounts.any((a) => (a['email'] as String).toLowerCase() == googleUser.email.toLowerCase())) {
                          if (Navigator.canPop(context)) Navigator.pop(context);
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(children: [Icon(Icons.info_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('This Google account is already saved for quick switch.'))]),
                              backgroundColor: Colors.blue[700],
                            ),
                          );
                          return;
                        }
                        
                        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
                        
                        // Just save the account info without signing in
                        if (Navigator.canPop(context)) Navigator.pop(context);
                        await _addQuickSwitchAccount({
                          'email': googleUser.email,
                          'uid': googleUser.id, // Use Google ID instead of Firebase UID
                          'password': 'google_sign_in',
                          'isGoogleAccount': true,
                          'accessToken': googleAuth.accessToken,
                          'idToken': googleAuth.idToken,
                        });
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('Google account added!'))]),
                            backgroundColor: Colors.green[600],
                          ),
                        );
                      } else {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      }
                    } catch (e) {
                      if (Navigator.canPop(context)) Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('Error adding Google account.'))]),
                          backgroundColor: Colors.red[700],
                        ),
                      );
                    }
                  },
                  child: Container(
                    height: 56,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset('assets/google_logo.png', height: 50),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text('Or sign in with email', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                SizedBox(height: 20),
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setDialogState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),            ElevatedButton(
              onPressed: () async {
                final email = _emailController.text.trim();
                final password = _passwordController.text.trim();
                
                if (email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('Please fill in all fields.'))]),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                  return;
                }
                
                if (email.toLowerCase() == _auth.currentUser?.email?.toLowerCase()) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [Icon(Icons.info_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('You are already authenticated with this account.'))]),
                      backgroundColor: Colors.blue[700],
                    ),
                  );
                  Navigator.of(context).pop();
                  return;
                }
                if (_quickSwitchAccounts.any((a) => (a['email'] as String).toLowerCase() == email.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [Icon(Icons.info_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('This account is already saved for quick switch.'))]),
                      backgroundColor: Colors.blue[700],
                    ),
                  );
                  Navigator.of(context).pop();
                  return;
                }
                  try {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(child: CircularProgressIndicator()),
                  );
                  
                  // For email/password accounts, we'll add them directly without validation
                  // The validation will happen when user tries to switch to this account
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  await _addQuickSwitchAccount({
                    'email': email,
                    'uid': '', // We'll get the UID when switching to the account
                    'password': password,
                    'isGoogleAccount': false,
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('Account added! Credentials will be validated when switching to this account.'))]),
                      backgroundColor: Colors.green[600],
                    ),
                  );
                } catch (e) {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('Could not add the account.'))]),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                }
              },
              child: Text('Add'),
            ),
          ],
        ),
      ),
    );
  }  Future<void> _changeProfilePicture() async {
    // Show image source dialog
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Image Source'),
          content: Text('Choose how you want to add the profile picture:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Camera'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library),
                  SizedBox(width: 8),
                  Text('Gallery'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );

    if (source != null) {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        try {
          // ✅ Use independent copy service for profile picture
          final String? copiedImagePath = await _imageCopyService.createImageCopy(image.path);
          
          if (copiedImagePath != null) {
            // Update profile photo path using independent copy
            await _auth.currentUser?.updatePhotoURL(copiedImagePath);

            // Save photo data in Firestore
            if (_auth.currentUser?.uid != null) {
              await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).set({
                'photoURL': copiedImagePath,
                'photoLocalPath': copiedImagePath,
              }, SetOptions(merge: true));
            }

            setState(() {}); // Refresh the UI
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(                children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Profile picture added successfuly!')),
                  ],
                ),
                backgroundColor: Colors.green[600],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: Duration(seconds: 2),
              ),
            );
          } else {
            // Fallback to use FileStorageService if copy fails
            final result = await _fileStorage.pickAndStoreImage(context: context);

            if (result != null) {
              final localPath = result['localPath'];
              
              await _auth.currentUser?.updatePhotoURL(localPath);

              if (_auth.currentUser?.uid != null) {
                await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).set({
                  'photoURL': localPath,
                  'photoLocalPath': localPath,
                }, SetOptions(merge: true));
              }

              setState(() {});
              
              ScaffoldMessenger.of(context).showSnackBar(                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(child: Text('Photo saved with original reference')),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(child: Text('Error updating profile picture')),
                ],
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }  // Helper method to get profile photo path from Firestore if not in Auth
  Future<String?> _getProfilePhotoUrl() async {
    if (_auth.currentUser?.photoURL != null && _auth.currentUser!.photoURL!.isNotEmpty) {
      return _auth.currentUser!.photoURL;
    }
    if (_auth.currentUser?.uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_auth.currentUser!.uid).get();
      if (doc.exists && doc.data()?['photoLocalPath'] != null) {
        return doc.data()!['photoLocalPath'] as String;
      }
    }
    return null;
  }

  // Helper method to check if an image file exists and is valid
  bool _doesFileExist(String? path) {
    if (path == null || path.isEmpty) return false;
    try {
      return File(path).existsSync();
    } catch (e) {
      print('Error checking if file exists: $e');
      return false;
    }
  }

  // Helper method to determine if the placeholder should be shown
  bool _shouldShowPlaceholder(String? path) {
    return !_doesFileExist(path);
  }

  // Helper method to build profile image
  ImageProvider? _buildProfileImage(String? path) {
    if (_doesFileExist(path)) {
      try {
        return FileImage(File(path!));
      } catch (e) {
        print('Error loading profile image: $e');
        return null;
      }
    }
    return null;
  }
  // Add account to quick switch list
  Future<void> _addQuickSwitchAccount(Map<String, dynamic> account) async {
    final emailLower = (account['email'] as String).toLowerCase();
    if (_quickSwitchAccounts.any((a) => (a['email'] as String).toLowerCase() == emailLower)) return;
    setState(() {
      _quickSwitchAccounts.add(account);
    });
    await _saveQuickSwitchAccounts();
  }
  // Remove account from quick switch list
  Future<void> _removeQuickSwitchAccount(String email) async {
    setState(() {
      _quickSwitchAccounts.removeWhere((a) => (a['email'] as String).toLowerCase() == email.toLowerCase());
    });
    await _saveQuickSwitchAccounts();
  }
  // Switch to a quick switch account
  Future<void> _switchToQuickAccount(Map<String, dynamic> account) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );
      
      // Save current account to quick switch list if not already there
      final currentUser = _auth.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final currentEmail = currentUser?.email ?? '';
      final currentPassword = prefs.getString('userPassword') ?? '';
      final currentUid = currentUser?.uid;
      final currentAccessToken = prefs.getString('accessToken');
      final currentIdToken = prefs.getString('idToken');
      final isCurrentGoogle = currentUser?.providerData.any((info) => info.providerId == 'google.com') ?? false;
      
      if (currentEmail.isNotEmpty && !_quickSwitchAccounts.any((a) => (a['email'] as String).toLowerCase() == currentEmail.toLowerCase())) {
        if (isCurrentGoogle && currentAccessToken != null && currentIdToken != null) {
          await _addQuickSwitchAccount({
            'email': currentEmail,
            'uid': currentUid,
            'password': 'google_sign_in',
            'isGoogleAccount': true,
            'accessToken': currentAccessToken,
            'idToken': currentIdToken,
          });
        } else if (currentPassword.isNotEmpty) {
          await _addQuickSwitchAccount({
            'email': currentEmail,
            'uid': currentUid,
            'password': currentPassword,
            'isGoogleAccount': false,
          });
        }
      }
      await FirebaseAuth.instance.signOut();      UserCredential userCredential;
      if (account['isGoogleAccount'] == true) {
        // Try to use saved tokens
        if ((account['accessToken'] ?? '').toString().isNotEmpty && (account['idToken'] ?? '').toString().isNotEmpty) {
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: account['accessToken'],
            idToken: account['idToken'],
          );
          userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        } else {
          // Force Google account selection
          await _googleSignIn.signOut();
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          if (googleUser == null || googleUser.email.toLowerCase() != (account['email'] as String).toLowerCase()) {
            throw Exception('Wrong Google account selected.');
          }
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          // Update saved tokens
          account['accessToken'] = googleAuth.accessToken;
          account['idToken'] = googleAuth.idToken;
          await _saveQuickSwitchAccounts();
        }
        await prefs.setString('userEmail', userCredential.user?.email ?? '');
        await prefs.setString('accessToken', account['accessToken'] ?? '');
        await prefs.setString('idToken', account['idToken'] ?? '');
        await prefs.remove('userPassword');
      } else {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: account['email'],
          password: account['password'],
        );
        await prefs.setString('userEmail', account['email']);
        await prefs.setString('userPassword', account['password']);
        await prefs.remove('accessToken');
        await prefs.remove('idToken');
      }      await prefs.setBool('isLoggedIn', true);
      setState(() {
        _email = userCredential.user?.email ?? account['email'];
        _username = _email.split('@')[0];
      });
      
      // Save this as the last active account for auto-login
      await _saveLastActiveAccount();
      
      await _loadQuickSwitchAccounts();
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('Account switched successfully!'))]),
          backgroundColor: Colors.green[600],
        ),
      );
      await Future.delayed(Duration(milliseconds: 400));
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => ListPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 10), Expanded(child: Text('Error switching account.'))]),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  // Save the current active account as the last used account
  Future<void> _saveLastActiveAccount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentUser = _auth.currentUser;
      
      if (currentUser?.email != null) {
        final currentEmail = currentUser!.email!;
        final currentPassword = prefs.getString('userPassword') ?? '';
        final currentAccessToken = prefs.getString('accessToken');
        final currentIdToken = prefs.getString('idToken');
        final isGoogleAccount = currentUser.providerData.any((info) => info.providerId == 'google.com');
        
        // Save last active account info
        await prefs.setString('lastActiveEmail', currentEmail);
        await prefs.setString('lastActiveUid', currentUser.uid);
        await prefs.setBool('lastActiveIsGoogle', isGoogleAccount);
        
        if (isGoogleAccount && currentAccessToken != null && currentIdToken != null) {
          await prefs.setString('lastActiveAccessToken', currentAccessToken);
          await prefs.setString('lastActiveIdToken', currentIdToken);
        } else if (!isGoogleAccount && currentPassword.isNotEmpty) {
          await prefs.setString('lastActivePassword', currentPassword);
        }
        
        print('Last active account saved: $currentEmail');
      }    } catch (e) {
      print('Error saving last active account: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFADD8E6),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(height: 20),
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 30),
                      // Profile Picture
                      FutureBuilder<String?>(
                        future: _getProfilePhotoUrl(),
                        builder: (context, snapshot) {
                          final photoUrl = snapshot.data;
                          return Stack(
                            alignment: Alignment.bottomRight,
                            children: [                              CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                backgroundImage: _buildProfileImage(photoUrl),
                                child: _shouldShowPlaceholder(photoUrl)
                                    ? Icon(
                                        Icons.person,
                                        size: 80,
                                        color: Colors.grey[400],
                                      )
                                    : null,
                              ),
                              GestureDetector(
                                onTap: _changeProfilePicture,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.camera_alt,
                                    size: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 30),
                      // User Information Section
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Username Field
                            _buildInfoRow(
                              icon: Icons.person,
                              label: 'Username',
                              value: _username,
                            ),
                            Divider(),
                            // Email Field
                            _buildInfoRow(
                              icon: Icons.email,
                              label: 'Email',
                              value: _email,
                            ),
                            Divider(),
                          ],
                        ),
                      ),
                      SizedBox(height: 25),
                      // Quick switch accounts section
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [                                Text(
                                  'Quick Switch Accounts',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle, color: Colors.blue),
                                  onPressed: _showAddAccountDialog,
                                ),
                              ],                            ),                            SizedBox(height: 15),
                            // Show all accounts (current user + quick switch accounts)
                            ...() {
                              final List<Widget> accountWidgets = [];
                              final Set<String> processedEmails = {};
                              
                              // First, add current user if not in quick switch list
                              final currentEmailLower = _email.toLowerCase();
                              if (!_quickSwitchAccounts.any((account) => account['email'].toLowerCase() == currentEmailLower)) {
                                accountWidgets.add(
                                  _buildAccountItem(
                                    email: _email,
                                    isActive: true,
                                    isGoogleAccount: _auth.currentUser?.providerData.any((info) => info.providerId == 'google.com') ?? false,
                                    onSwitch: () {},
                                    onRemove: () {}, // Current user can't be removed when not in list
                                  )
                                );
                                processedEmails.add(currentEmailLower);
                              }
                              
                              // Then add all accounts from quick switch list
                              for (var account in _quickSwitchAccounts) {
                                final accountEmailLower = account['email'].toLowerCase();
                                if (!processedEmails.contains(accountEmailLower)) {
                                  final isCurrentUser = accountEmailLower == currentEmailLower;
                                  accountWidgets.add(
                                    _buildAccountItem(
                                      email: account['email'],
                                      isActive: isCurrentUser,
                                      isGoogleAccount: account['isGoogleAccount'] == true,
                                      onSwitch: isCurrentUser ? () {} : () => _switchToQuickAccount(account),
                                      onRemove: isCurrentUser ? () {} : () => _removeQuickSwitchAccount(account['email']),
                                    )
                                  );
                                  processedEmails.add(accountEmailLower);
                                }
                              }
                              
                              return accountWidgets;
                            }(),
                          ],
                        ),
                      ),
                      SizedBox(height: 25),
                      // Notification Settings
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => NotificationSettingsPage()),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.notifications, color: Colors.blue),
                                SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Notification Settings',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        'Configure warranty expiry notifications',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.arrow_forward_ios, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                      // Logout Button
                      ElevatedButton(
                        onPressed: _logout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.logout),
                            SizedBox(width: 10),
                            Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}


