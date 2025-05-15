import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:mywarranties/main.dart' as app;
import 'package:mywarranties/list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_settings.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool _isLoading = true;
  String _username = '';
  String _email = '';
  String _password = '••••••••';
  List<Map<String, dynamic>> _accounts = [];
  
  // Controller for adding new account
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Clean up any duplicate accounts that might be in SharedPreferences
    _cleanupDuplicateAccounts();
  }
  
  // Clean up any duplicate accounts in SharedPreferences
  Future<void> _cleanupDuplicateAccounts() async {
    try {
      print('Cleaning up duplicate accounts...');
      
      // Get the raw list from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final linkedAccountsJson = prefs.getStringList('linkedAccounts') ?? [];
      
      print('Found ${linkedAccountsJson.length} accounts in SharedPreferences');
      
      // Process the list to remove duplicates
      final Set<String> emailsAdded = {};
      final List<String> uniqueAccounts = [];
      
      // Get current user email (if any)
      final currentUserEmail = _auth.currentUser?.email?.toLowerCase() ?? '';
      if (currentUserEmail.isNotEmpty) {
        emailsAdded.add(currentUserEmail);
        print('Current user email: $currentUserEmail (will be preserved)');
      }
      
      // First add the current user account
      for (String accountJson in linkedAccountsJson) {
        final parts = accountJson.split(':::');
        if (parts.length >= 3) {
          final email = parts[0];
          final emailLower = email.toLowerCase();
          
          if (emailLower == currentUserEmail) {
            uniqueAccounts.add(accountJson);
            print('Preserved current user account: $email');
            break;
          }
        }
      }
      
      // Then add all other unique accounts
      for (String accountJson in linkedAccountsJson) {
        final parts = accountJson.split(':::');
        if (parts.length >= 3) {
          final email = parts[0];
          final emailLower = email.toLowerCase();
          
          if (emailLower != currentUserEmail && !emailsAdded.contains(emailLower)) {
            uniqueAccounts.add(accountJson);
            emailsAdded.add(emailLower);
            print('Preserved unique account: $email');
          } else if (emailLower != currentUserEmail) {
            print('Removed duplicate account: $email');
          }
        }
      }
      
      // Save the cleaned list back to SharedPreferences
      await prefs.setStringList('linkedAccounts', uniqueAccounts);
      print('Saved ${uniqueAccounts.length} unique accounts to SharedPreferences');
      
      // Now load the cleaned accounts into memory
      await _loadLinkedAccounts();
    } catch (e) {
      print('Error cleaning up duplicate accounts: $e');
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
        // Load linked accounts from SharedPreferences
        await _loadLinkedAccounts();
        
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
  }
  
  // Load linked accounts from SharedPreferences
  Future<void> _loadLinkedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final linkedAccountsJson = prefs.getStringList('linkedAccounts') ?? [];
      
      print('Loading linked accounts: ${linkedAccountsJson.length} accounts found');
      
      final List<Map<String, dynamic>> loadedAccounts = [];
      final Set<String> addedEmails = {}; // Track emails to prevent duplicates
      
      // Get current user email (if any)
      final currentUserEmail = _auth.currentUser?.email?.toLowerCase() ?? '';
      if (currentUserEmail.isNotEmpty) {
        addedEmails.add(currentUserEmail);
        print('Current user email: $currentUserEmail (will be excluded from linked accounts)');
      }
      
      for (String accountJson in linkedAccountsJson) {
        final Map<String, dynamic> account = {};
        final parts = accountJson.split(':::');
        if (parts.length >= 3) {
          final email = parts[0];
          final emailLower = email.toLowerCase();
          
          print('Processing account: $email');
          
          // Skip if this is the current user or if we've already added this email
          if (emailLower == currentUserEmail || addedEmails.contains(emailLower)) {
            print('Skipping account $email (current user or duplicate)');
            continue;
          }
          
          account['email'] = email;
          account['uid'] = parts[1];
          account['password'] = parts[2];
          
          loadedAccounts.add(account);
          addedEmails.add(emailLower);
          print('Added account: $email to linked accounts');
        }
      }
      
      print('Final linked accounts count: ${loadedAccounts.length}');
      
      setState(() {
        _accounts = loadedAccounts;
      });
    } catch (e) {
      print('Error loading linked accounts: $e');
    }
  }
  
  // Save linked accounts to SharedPreferences
  Future<void> _saveLinkedAccounts() async {
    try {
      print('Saving linked accounts...');
      print('Current accounts in memory: ${_accounts.length}');
      
      final prefs = await SharedPreferences.getInstance();
      final List<String> accountsToSave = [];
      final Set<String> emailsAdded = {}; // Track emails to prevent duplicates
      
      // Add current user to the list first
      if (_auth.currentUser != null && _auth.currentUser!.email != null) {
        final currentUserEmail = _auth.currentUser!.email!;
        final currentUserPassword = prefs.getString('userPassword') ?? '';
        accountsToSave.add('$currentUserEmail:::${_auth.currentUser!.uid}:::$currentUserPassword');
        emailsAdded.add(currentUserEmail.toLowerCase());
        print('Added current user to save list: $currentUserEmail');
      }
      
      // Add other linked accounts (avoiding duplicates)
      for (var account in _accounts) {
        final email = account['email'] as String;
        if (!emailsAdded.contains(email.toLowerCase())) {
          accountsToSave.add('$email:::${account['uid']}:::${account['password']}');
          emailsAdded.add(email.toLowerCase());
          print('Added linked account to save list: $email');
        } else {
          print('Skipping duplicate account: $email');
        }
      }
      
      print('Total accounts to save: ${accountsToSave.length}');
      await prefs.setStringList('linkedAccounts', accountsToSave);
      
      // Verify what was saved
      final savedAccounts = prefs.getStringList('linkedAccounts') ?? [];
      print('Accounts saved to SharedPreferences: ${savedAccounts.length}');
      for (var account in savedAccounts) {
        final parts = account.split(':::');
        if (parts.isNotEmpty) {
          print('Saved account: ${parts[0]}');
        }
      }
    } catch (e) {
      print('Error saving linked accounts: $e');
    }
  }

  void _logout() {
    // Mostrar diálogo de confirmação
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Fechar o diálogo primeiro
              Navigator.of(context).pop();
              
              // Executar o logout sem bloqueio
              _performLogout();
            },
            child: Text('Logout'),
          ),
        ],
      ),
    );
  }
  
  // Método separado para realizar o logout sem bloquear a UI
  void _performLogout() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );
      
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
      await _auth.signOut();
      
      // Clear SharedPreferences except linked accounts
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('isLoggedIn', false);
      prefs.remove('userEmail');
      prefs.remove('userPassword');
      prefs.remove('accessToken');
      prefs.remove('idToken');
      prefs.remove('deviceToken');
      
      // Close loading dialog
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Navigate to the welcome screen
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => app.MyApp()),
        (route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during logout. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
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
  }

  Widget _buildAccountItem({
    required String email,
    required bool isActive,
    required VoidCallback onSwitch,
    required VoidCallback onRemove,
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
          Icon(
            Icons.account_circle,
            color: isActive ? Colors.blue : Colors.grey,
            size: 28,
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? Colors.black87 : Colors.black54,
                  ),
                ),
                if (isActive)
                  Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                    ),
                  ),
              ],
            ),
          ),
          if (!isActive)
            Row(
              children: [
                TextButton(
                  onPressed: onSwitch,
                  child: Text('Login', style: TextStyle(color: Colors.blue)),
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
    // Reset controllers
    _emailController.clear();
    _passwordController.clear();
    _isPasswordVisible = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Add Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      ),
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
            ),
            ElevatedButton(
              onPressed: () async {
                final email = _emailController.text.trim();
                final password = _passwordController.text.trim();
                
                // Check if account is already linked or is the current account
                if (email == _auth.currentUser?.email) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(child: Text('You are already signed in with this account')),
                        ],
                      ),
                      backgroundColor: Colors.blue[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  Navigator.of(context).pop();
                  return;
                }
                
                for (var account in _accounts) {
                  if (account['email'] == email) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.white),
                            SizedBox(width: 10),
                            Expanded(child: Text('This account is already linked to your profile')),
                          ],
                        ),
                        backgroundColor: Colors.blue[700],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    );
                    Navigator.of(context).pop();
                    return;
                  }
                }

                try {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                  
                  // Save current user credentials
                  final prefs = await SharedPreferences.getInstance();
                  final currentEmail = _auth.currentUser?.email ?? '';
                  final currentPassword = prefs.getString('userPassword') ?? '';
                  final currentUid = _auth.currentUser?.uid;
                  
                  // Sign out from the current account
                  await FirebaseAuth.instance.signOut();
                  
                  // Temporarily sign in to validate the credentials
                  final tempUserCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: email,
                    password: password,
                  );
                  
                  final newUid = tempUserCredential.user?.uid;

                  // Immediately sign out the validated account
                  await FirebaseAuth.instance.signOut();

                  // Re-authenticate the current user
                  if (currentEmail.isNotEmpty && currentPassword.isNotEmpty) {
                    await FirebaseAuth.instance.signInWithEmailAndPassword(
                      email: currentEmail,
                      password: currentPassword,
                    );
                  }
                  
                  // Close loading dialog
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  print('Adding new account: $email');
                  
                  // Add the validated account to the linked accounts list
                  setState(() {
                    // Make a copy of the current accounts list
                    final updatedAccounts = List<Map<String, dynamic>>.from(_accounts);
                    
                    // Add the new account
                    updatedAccounts.add({
                      'email': email,
                      'uid': newUid,
                      'password': password, // Store password for switching accounts
                    });
                    
                    // Update the accounts list
                    _accounts = updatedAccounts;
                    print('Updated accounts list after adding: ${_accounts.length} accounts');
                    for (var acc in _accounts) {
                      print('Account in list: ${acc['email']}');
                    }
                  });
                  
                  // Save updated linked accounts
                  await _saveLinkedAccounts();

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(child: Text('Account linked successfully!')),
                        ],
                      ),
                      backgroundColor: Colors.green[600],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                  
                  // Refresh the profile page to ensure the UI is updated
                  setState(() {});
                } catch (e) {
                  // Close loading dialog if it's open
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  
                  // Show error message
                  // Extract a more user-friendly error message
                  String errorMessage = "Unable to link account. Please check your credentials and try again.";
                  if (e is FirebaseAuthException) {
                    switch (e.code) {
                      case 'user-not-found':
                        errorMessage = "No account found with this email. Please check or create a new account.";
                        break;
                      case 'wrong-password':
                        errorMessage = "Incorrect password. Please try again.";
                        break;
                      case 'invalid-email':
                        errorMessage = "Please enter a valid email address.";
                        break;
                    }
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.white),
                          SizedBox(width: 10),
                          Expanded(child: Text(errorMessage)),
                        ],
                      ),
                      backgroundColor: Colors.red[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      duration: Duration(seconds: 4),
                    ),
                  );
                  
                  // If an error occurred during validation, make sure we're logged back in
                  try {
                    final prefs = await SharedPreferences.getInstance();
                    final currentEmail = prefs.getString('userEmail') ?? '';
                    final currentPassword = prefs.getString('userPassword') ?? '';
                    
                    if (currentEmail.isNotEmpty && currentPassword.isNotEmpty) {
                      await FirebaseAuth.instance.signInWithEmailAndPassword(
                        email: currentEmail,
                        password: currentPassword,
                      );
                    }
                  } catch (loginError) {
                    print('Error re-authenticating after validation error: $loginError');
                  }
                }
              },
              child: Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeProfilePicture() async {
    // Use an image picker to select a new profile picture
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      try {
        // Upload the image to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref().child('profile_pictures/${_auth.currentUser?.uid}.jpg');
        await storageRef.putFile(File(image.path));

        // Get the download URL and update the user's profile
        final downloadUrl = await storageRef.getDownloadURL();
        await _auth.currentUser?.updatePhotoURL(downloadUrl);

        setState(() {}); // Refresh the UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Profile picture updated successfully!')),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Unable to update profile picture. Please try again.')),
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
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            backgroundImage: _auth.currentUser?.photoURL != null
                                ? NetworkImage(_auth.currentUser!.photoURL!)
                                : null,
                            child: _auth.currentUser?.photoURL == null
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
                      // Multi-Account Section
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
                              children: [
                                Text(
                                  'Linked Accounts',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.add_circle, color: Colors.blue),
                                  onPressed: _showAddAccountDialog,
                                ),
                              ],
                            ),
                            SizedBox(height: 15),
                            // Current account (primary)
                            _buildAccountItem(
                              email: _email,
                              isActive: true,
                              onSwitch: () {}, // No switch for the active account
                              onRemove: () {}, // No remove for the active account
                            ),
                            // Linked accounts
                            ..._accounts.map((account) => _buildAccountItem(
                                  email: account['email'],
                                  isActive: false,
                                  onSwitch: () async {
                                    try {
                                      // Show loading indicator
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                      );
                                      
                                      // Get current user info to add to linked accounts
                                      final currentEmail = _auth.currentUser?.email ?? '';
                                      final prefs = await SharedPreferences.getInstance();
                                      final currentPassword = prefs.getString('userPassword') ?? '';
                                      final currentUid = _auth.currentUser?.uid;
                                      
                                      print('Switching from $currentEmail to ${account['email']}');
                                      
                                      // Create a copy of the account we're switching to
                                      final switchToAccount = Map<String, dynamic>.from(account);
                                      
                                      // Prepare the updated accounts list but don't update the UI yet
                                      final updatedAccounts = List<Map<String, dynamic>>.from(_accounts);
                                      
                                      // Remove the account we're switching to from linked accounts
                                      updatedAccounts.removeWhere((a) => 
                                        a['email'].toString().toLowerCase() == switchToAccount['email'].toString().toLowerCase());
                                      
                                      // Add the previous account to linked accounts if it's valid and not already in the list
                                      if (currentEmail.isNotEmpty && currentPassword.isNotEmpty) {
                                        // Check if this account is already in the list
                                        final accountExists = updatedAccounts.any((a) => 
                                          a['email'].toString().toLowerCase() == currentEmail.toLowerCase());
                                        
                                        if (!accountExists) {
                                          updatedAccounts.add({
                                            'email': currentEmail,
                                            'uid': currentUid,
                                            'password': currentPassword,
                                          });
                                          print('Added current account to linked accounts: $currentEmail');
                                        } else {
                                          print('Current account already exists in linked accounts: $currentEmail');
                                        }
                                      }
                                      
                                      print('Prepared updated accounts list: ${updatedAccounts.length} accounts');
                                      for (var acc in updatedAccounts) {
                                        print('Account in prepared list: ${acc['email']}');
                                      }
                                      
                                      // We'll update the UI and save to SharedPreferences after the authentication is complete
                                      
                                      // Completely sign out the current user
                                      await FirebaseAuth.instance.signOut();
                                      
                                      // Sign in with the new account using the login logic from login.dart
                                      final UserCredential userCredential = await FirebaseAuth.instance
                                          .signInWithEmailAndPassword(
                                        email: account['email'],
                                        password: account['password'],
                                      );
                                      
                                      final User? user = userCredential.user;
                                      
                                      if (user != null) {
                                        // Check if the account is already logged in on another device
                                        final idTokenResult = await user.getIdTokenResult(true);
                                        final claims = idTokenResult.claims;
                                        
                                        if (claims != null && claims['isLoggedIn'] == true) {
                                          // Send notification to the other device
                                          await FirebaseFirestore.instance
                                              .collection('notifications')
                                              .doc(user.uid)
                                              .set({
                                            'message': 'You have been logged out because your account was accessed on another device.',
                                            'timestamp': FieldValue.serverTimestamp(),
                                          });
                                        }
                                        
                                        // Update login state for the current device
                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(user.uid)
                                            .set({
                                          'isLoggedIn': true,
                                        }, SetOptions(merge: true));
                                        
                                        // Update SharedPreferences with new user credentials
                                        await prefs.setString('userEmail', account['email']);
                                        await prefs.setString('userPassword', account['password']);
                                        await prefs.setBool('isLoggedIn', true);
                                        
                                        // Clear any other authentication tokens
                                        await prefs.remove('accessToken');
                                        await prefs.remove('idToken');
                                        
                                        // Now that authentication is complete, update the UI state
                                        // This prevents the UI from showing duplicate accounts during the transition
                                        setState(() {
                                          _accounts = updatedAccounts;
                                          _email = user.email ?? account['email'];
                                          _username = _email.split('@')[0];
                                        });
                                        
                                        // We'll save to SharedPreferences after authentication is complete
                                      }
                                      
                                      // Close loading dialog
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                      
                                      // Show success message
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white),
                                              SizedBox(width: 10),
                                              Expanded(child: Text('Successfully switched to ${account['email']}')),
                                            ],
                                          ),
                                          backgroundColor: Colors.green[600],
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                      
                                      // Use a slightly longer delay before navigation to ensure Firebase Auth has completed its operations
                                      // This helps prevent the loading screen from getting stuck
                                      await Future.delayed(Duration(milliseconds: 500));
                                      
                                      // Navigate directly to the ListPage to show the new user's content
                                      if (mounted) {
                                        // Navigate to the ListPage, removing all previous routes
                                        Navigator.of(context).pushAndRemoveUntil(
                                          MaterialPageRoute(builder: (context) => ListPage()),
                                          (route) => false,
                                        );
                                      }
                                    } catch (e) {
                                      print('Error switching account: $e');
                                      
                                      // Close loading dialog
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.error_outline, color: Colors.white),
                                              SizedBox(width: 10),
                                              Expanded(child: Text('Unable to switch accounts. Please try again later.')),
                                            ],
                                          ),
                                          backgroundColor: Colors.red[700],
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          duration: Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                  onRemove: () async {
                                    // Show confirmation dialog
                                    final shouldRemove = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('Remove Account'),
                                        content: Text('Are you sure you want to remove ${account['email']} from linked accounts?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: Text('Remove', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    ) ?? false;
                                    
                                    if (shouldRemove) {
                                      print('Removing account: ${account['email']}');
                                      
                                      // Create a copy of the account we're removing
                                      final accountToRemove = Map<String, dynamic>.from(account);
                                      
                                      setState(() {
                                        // Make a copy of the current accounts list
                                        final updatedAccounts = List<Map<String, dynamic>>.from(_accounts);
                                        
                                        // Remove the account by email (case insensitive)
                                        updatedAccounts.removeWhere((a) => 
                                          a['email'].toString().toLowerCase() == accountToRemove['email'].toString().toLowerCase());
                                        
                                        // Update the accounts list
                                        _accounts = updatedAccounts;
                                        print('Updated accounts list after removal: ${_accounts.length} accounts');
                                      });
                                      
                                      // Save updated linked accounts
                                      await _saveLinkedAccounts();
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Row(
                                            children: [
                                              Icon(Icons.check_circle, color: Colors.white),
                                              SizedBox(width: 10),
                                              Expanded(child: Text('${accountToRemove['email']} has been unlinked from your profile')),
                                            ],
                                          ),
                                          backgroundColor: Colors.green[600],
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                    }
                                  },
                                )),
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
