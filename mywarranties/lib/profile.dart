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
        
        // Check if this is in the new format (with isGoogleAccount flag)
        if (parts.length >= 6) {
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
          account['isGoogleAccount'] = parts[3] == 'true';
          account['accessToken'] = parts[4];
          account['idToken'] = parts[5];
          
          loadedAccounts.add(account);
          addedEmails.add(emailLower);
          print('Added account: $email to linked accounts (${account['isGoogleAccount'] ? "Google" : "Email"})');
        } 
        // Support for old format
        else if (parts.length >= 3) {
          final email = parts[0];
          final emailLower = email.toLowerCase();
          
          print('Processing account (old format): $email');
          
          // Skip if this is the current user or if we've already added this email
          if (emailLower == currentUserEmail || addedEmails.contains(emailLower)) {
            print('Skipping account $email (current user or duplicate)');
            continue;
          }
          
          account['email'] = email;
          account['uid'] = parts[1];
          account['password'] = parts[2];
          account['isGoogleAccount'] = parts[2] == 'google_sign_in';
          
          loadedAccounts.add(account);
          addedEmails.add(emailLower);
          print('Added account: $email to linked accounts (old format)');
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
        final currentUserUid = _auth.currentUser!.uid;
        final currentUserPassword = prefs.getString('userPassword') ?? '';
        final accessToken = prefs.getString('accessToken') ?? '';
        final idToken = prefs.getString('idToken') ?? '';
        
        // Check if this is a Google account
        if (accessToken.isNotEmpty && idToken.isNotEmpty) {
          accountsToSave.add('$currentUserEmail:::$currentUserUid:::google_sign_in:::true:::$accessToken:::$idToken');
        } else {
          accountsToSave.add('$currentUserEmail:::$currentUserUid:::$currentUserPassword:::false::::::');
        }
        
        emailsAdded.add(currentUserEmail.toLowerCase());
        print('Added current user to save list: $currentUserEmail');
      }
      
      // Add other linked accounts (avoiding duplicates)
      for (var account in _accounts) {
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
          print('Added linked account to save list: $email (${isGoogleAccount ? "Google" : "Email"})');
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
          print('Saved account: ${parts[0]} (${parts.length >= 4 && parts[3] == "true" ? "Google" : "Email"})');
        }
      }
    } catch (e) {
      print('Error saving linked accounts: $e');
    }
  }
  Future<void> _logout() async {
    // Mostrar diálogo de confirmação e aguardar resposta
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Logout'),
        content: Text('Are you sure you want to logout?'),
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
    
    // Se o usuário cancelou ou fechou o diálogo, não faça nada
    if (confirmLogout != true) return;
    
    // Mostrar loading com useRootNavigator para garantir que possa ser fechado corretamente
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
      
      // Aguarda um pequeno delay para garantir que todas operações terminaram
      await Future.delayed(Duration(milliseconds: 300));
      
      // Fecha o diálogo de loading com rootNavigator
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      
      // Aguarda mais um pequeno delay para garantir que UI está estável
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
      
      // Fecha o diálogo de loading se estiver aberto
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
  }
  Widget _buildAccountItem({
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
                height: 28,                decoration: BoxDecoration(
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
                // Google Sign-In Button
                InkWell(                  onTap: () async {
                    try {
                      // Show loading indicator
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => Center(
                          child: CircularProgressIndicator(),
                        ),
                      );                      // Force sign out of Google to ensure account selection dialog shows
                      await _googleSignIn.signOut();
                      await Future.delayed(Duration(milliseconds: 500));
                      
                      // Show message to select a different account
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please select a different Google account to link'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      
                      // Get current user's email for comparison
                      final currentUserEmail = _auth.currentUser?.email?.toLowerCase() ?? '';
                      
                      // Start sign-in process with account selector
                      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

                      if (googleUser != null) {
                        try {
                          // Check if the selected Google account is the same as current account
                          if (googleUser.email.toLowerCase() == currentUserEmail) {
                            // Close loading dialog
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                            
                            // Close the add account dialog
                            Navigator.of(context).pop();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.white),
                                    SizedBox(width: 10),
                                    Expanded(child: Text('You selected the same account you are already signed in with. Please select a different Google account.')),
                                  ],
                                ),
                                backgroundColor: Colors.orange,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                            return;                          }
                          
                          // Get Google account details
                          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
                          
                          // Create Firebase credential with Google token
                          final AuthCredential credential = GoogleAuthProvider.credential(
                            accessToken: googleAuth.accessToken,
                            idToken: googleAuth.idToken,
                          );

                          // Save current user credentials before any changes
                          final currentUser = _auth.currentUser;
                          final currentEmail = currentUser?.email ?? '';
                          final prefs = await SharedPreferences.getInstance();
                          final currentPassword = prefs.getString('userPassword') ?? '';
                          final currentIsGoogle = currentUser?.providerData
                              .any((info) => info.providerId == 'google.com') ?? false;
                          final currentAccessToken = prefs.getString('accessToken');
                          final currentIdToken = prefs.getString('idToken');
                          
                          // Check if this Google account is already linked
                          final existingGoogle = _accounts.where((account) => 
                            account['email'].toString().toLowerCase() == googleUser.email.toLowerCase() && account['isGoogleAccount'] == true).toList();
                          
                          if (existingGoogle.isNotEmpty) {
                            // Close loading dialog
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                            
                            // Close the add account dialog
                            Navigator.of(context).pop();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.white),
                                    SizedBox(width: 10),
                                    Expanded(child: Text('This Google account is already linked to your profile')),
                                  ],
                                ),
                                backgroundColor: Colors.blue[700],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                            return;
                          }
                          
                          // Current user's Google account check - Case insensitive comparison
                          if (currentEmail.toLowerCase() == googleUser.email.toLowerCase()) {
                            // Close loading dialog
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }
                            
                            // Close the add account dialog
                            Navigator.of(context).pop();
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: Colors.white),
                                    SizedBox(width: 10),
                                    Expanded(child: Text('You are already signed in with this Google account')),
                                  ],
                                ),
                                backgroundColor: Colors.blue[700],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                            return;
                          }

                          // Temporarily sign in with Google to validate the new account
                          final UserCredential tempCredential = await FirebaseAuth.instance.signInWithCredential(credential);
                          final User? tempUser = tempCredential.user;

                          if (tempUser != null) {
                            // Save the Google account info
                            final googleAccountInfo = {
                              'email': tempUser.email,
                              'uid': tempUser.uid,
                              'password': 'google_sign_in',
                              'isGoogleAccount': true,
                              'accessToken': googleAuth.accessToken,
                              'idToken': googleAuth.idToken,
                            };

                            // Sign out the temporary Google account
                            await FirebaseAuth.instance.signOut();

                            // Re-authenticate the original current user
                            if (currentIsGoogle && currentAccessToken != null && currentIdToken != null) {
                              // Re-authenticate with Google credentials
                              final AuthCredential currentCredential = GoogleAuthProvider.credential(
                                accessToken: currentAccessToken,
                                idToken: currentIdToken,
                              );
                              await FirebaseAuth.instance.signInWithCredential(currentCredential);
                            } else if (currentEmail.isNotEmpty && currentPassword.isNotEmpty) {
                              // Re-authenticate with email/password
                              await FirebaseAuth.instance.signInWithEmailAndPassword(
                                email: currentEmail,
                                password: currentPassword,
                              );
                            }

                            // Close loading dialog
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }

                            // Add the Google account to linked accounts
                            setState(() {
                              final updatedAccounts = List<Map<String, dynamic>>.from(_accounts);
                              updatedAccounts.add(googleAccountInfo);
                              _accounts = updatedAccounts;
                            });

                            // Save updated linked accounts
                            await _saveLinkedAccounts();

                            // Close the add account dialog
                            Navigator.of(context).pop();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 10),
                                    Expanded(child: Text('Google account linked successfully!')),
                                  ],
                                ),
                                backgroundColor: Colors.green[600],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error during Google sign in: $e');
                          // Close loading dialog if it's open
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }

                          // Show error message
                          String errorMessage = 'Error signing in with Google. Please try again.';
                          if (e is FirebaseAuthException) {
                            switch (e.code) {
                              case 'account-exists-with-different-credential':
                                errorMessage = 'This email is already linked to a different account type.';
                                break;
                              case 'invalid-credential':
                                errorMessage = 'Invalid Google credentials. Please try again.';
                                break;
                              case 'user-disabled':
                                errorMessage = 'This account has been disabled.';
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

                          // Re-authenticate the current user
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
                            print('Error re-authenticating after Google sign-in error: $loginError');
                          }
                        }
                      } else {
                        // Close loading dialog if it's open
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }
                    } catch (e) {
                      print('Error initiating Google sign in: $e');
                      // Close loading dialog if it's open
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      }

                      // Show error message
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.white),
                              SizedBox(width: 10),
                              Expanded(child: Text('Error signing in with Google. Please try again.')),
                            ],
                          ),
                          backgroundColor: Colors.red[700],
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          duration: Duration(seconds: 4),
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
                        mainAxisAlignment: MainAxisAlignment.center,                        children: [
                          Image.asset(
                            'assets/google_logo.png',
                            height: 50,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Or sign in with email',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 20),
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
                  // Check if account is already linked or is the current account - Case insensitive
                if (email.toLowerCase() == _auth.currentUser?.email?.toLowerCase()) {
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
                  if (account['email'].toString().toLowerCase() == email.toLowerCase()) {
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
                      'password': password,
                      'isGoogleAccount': false,
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
          // ✅ Usar serviço de cópias independentes para foto de perfil
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
            // Fallback para usar o FileStorageService se a cópia falhar
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
                              isGoogleAccount: _auth.currentUser?.providerData
                                  .any((info) => info.providerId == 'google.com') ?? false,
                              onSwitch: () {}, // No switch for the active account
                              onRemove: () {}, // No remove for the active account
                            ),
                            // Linked accounts
                            ..._accounts.map((account) => _buildAccountItem(
                                  email: account['email'],
                                  isActive: false,
                                  isGoogleAccount: account['isGoogleAccount'] == true,
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
                                      final currentUser = _auth.currentUser;
                                      final currentAccessToken = prefs.getString('accessToken');
                                      final currentIdToken = prefs.getString('idToken');
                                      
                                      print('Switching from $currentEmail to ${account['email']}');
                                      
                                      // Create a copy of the account we're switching to
                                      final switchToAccount = Map<String, dynamic>.from(account);
                                      
                                      // Prepare the updated accounts list but don't update the UI yet
                                      final updatedAccounts = List<Map<String, dynamic>>.from(_accounts);
                                      
                                      // Remove the account we're switching to from linked accounts
                                      updatedAccounts.removeWhere((a) => 
                                        a['email'].toString().toLowerCase() == switchToAccount['email'].toString().toLowerCase());
                                        // Add the previous account to linked accounts if it's valid and not already in the list
                                      if (currentEmail.isNotEmpty && (currentPassword.isNotEmpty || (currentAccessToken != null && currentIdToken != null))) {
                                        // Check if this account is already in the list
                                        final accountExists = updatedAccounts.any((a) => 
                                          a['email'].toString().toLowerCase() == currentEmail.toLowerCase());
                                        
                                        if (!accountExists) {
                                          // Determine if current account is Google account
                                          final currentIsGoogleAccount = currentUser?.providerData
                                              .any((info) => info.providerId == 'google.com') ?? false;
                                          
                                          if (currentIsGoogleAccount && currentAccessToken != null && currentIdToken != null) {
                                            updatedAccounts.add({
                                              'email': currentEmail,
                                              'uid': currentUid,
                                              'password': 'google_sign_in',
                                              'isGoogleAccount': true,
                                              'accessToken': currentAccessToken,
                                              'idToken': currentIdToken,
                                            });
                                            print('Added current Google account to linked accounts: $currentEmail');
                                          } else {
                                            updatedAccounts.add({
                                              'email': currentEmail,
                                              'uid': currentUid,
                                              'password': currentPassword,
                                              'isGoogleAccount': false,
                                            });
                                            print('Added current email account to linked accounts: $currentEmail');
                                          }
                                        } else {
                                          print('Current account already exists in linked accounts: $currentEmail');
                                        }
                                      }
                                      
                                      print('Prepared updated accounts list: ${updatedAccounts.length} accounts');
                                      for (var acc in updatedAccounts) {
                                        print('Account in prepared list: ${acc['email']}');
                                      }
                                        // Completely sign out the current user
                                      await FirebaseAuth.instance.signOut();
                                      
                                      // Sign in with the new account
                                      UserCredential userCredential;
                                      GoogleSignInAuthentication? googleAuth;
                                      
                                      if (switchToAccount['isGoogleAccount'] == true) {
                                        // Handle Google Sign-In using saved tokens first
                                        try {
                                          print('Attempting to switch to Google account using saved tokens: ${switchToAccount['email']}');
                                          
                                          // Try using saved tokens first if available
                                          if (switchToAccount['accessToken'] != null && 
                                              switchToAccount['idToken'] != null &&
                                              switchToAccount['accessToken'].toString().isNotEmpty &&
                                              switchToAccount['idToken'].toString().isNotEmpty) {
                                            
                                            print('Using saved Google tokens for ${switchToAccount['email']}');
                                            
                                            final AuthCredential credential = GoogleAuthProvider.credential(
                                              accessToken: switchToAccount['accessToken'],
                                              idToken: switchToAccount['idToken'],
                                            );
                                            
                                            userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
                                            
                                            // Verify that we signed in with the correct account
                                            if (userCredential.user?.email?.toLowerCase() == switchToAccount['email'].toString().toLowerCase()) {
                                              print('Successfully switched using saved tokens');
                                              googleAuth = null; // No need for new auth since we used saved tokens
                                            } else {
                                              throw Exception('Token mismatch - need fresh authentication');
                                            }
                                          } else {
                                            throw Exception('No saved tokens available - need fresh authentication');
                                          }
                                        } catch (tokenError) {
                                          print('Saved tokens failed, attempting fresh Google sign-in: $tokenError');
                                          
                                          // Fall back to fresh Google sign-in only if saved tokens fail
                                          try {
                                            // Always sign out first to force account selection
                                            await _googleSignIn.signOut();
                                            
                                            // Show message to user about which account to select
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Please sign in with ${switchToAccount['email']}'),
                                                duration: Duration(seconds: 2),
                                              ),
                                            );
                                            
                                            // Small delay to ensure signout completes and message is seen
                                            await Future.delayed(Duration(milliseconds: 500));
                                            
                                            // Try with explicit sign-in to force account selection
                                            final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
                                            
                                            if (googleUser == null) {
                                              throw Exception('Google Sign-In was cancelled');
                                            }
                                            
                                            // Verify that the signed-in Google account matches the one we're trying to switch to
                                            if (googleUser.email.toLowerCase() != switchToAccount['email'].toString().toLowerCase()) {
                                              // Wrong account selected
                                              await _googleSignIn.signOut();
                                              throw Exception('Incorrect Google account selected. Please try again and select ${switchToAccount['email']}.');
                                            }
                                            
                                            googleAuth = await googleUser.authentication;
                                            
                                            final AuthCredential credential = GoogleAuthProvider.credential(
                                              accessToken: googleAuth.accessToken,
                                              idToken: googleAuth.idToken,
                                            );
                                            
                                            userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
                                            
                                            // Update stored tokens with fresh ones
                                            if (googleAuth.accessToken != null && googleAuth.idToken != null) {
                                              switchToAccount['accessToken'] = googleAuth.accessToken;
                                              switchToAccount['idToken'] = googleAuth.idToken;
                                            }
                                          } catch (e) {
                                            print('Fresh Google sign-in also failed: $e');
                                            rethrow;
                                          }
                                        }
                                      } else {
                                        // Handle email/password sign-in
                                        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                                          email: switchToAccount['email'],
                                          password: switchToAccount['password'],
                                        );
                                      }
                                      
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
                                        await prefs.setString('userEmail', user.email ?? '');
                                        if (switchToAccount['isGoogleAccount'] == true) {
                                          // For Google accounts, use either fresh tokens or saved tokens
                                          if (googleAuth != null) {
                                            // Fresh tokens from new authentication
                                            await prefs.setString('accessToken', googleAuth.accessToken ?? '');
                                            await prefs.setString('idToken', googleAuth.idToken ?? '');
                                          } else {
                                            // Use saved tokens that were used for authentication
                                            await prefs.setString('accessToken', switchToAccount['accessToken'] ?? '');
                                            await prefs.setString('idToken', switchToAccount['idToken'] ?? '');
                                          }
                                          await prefs.remove('userPassword');
                                        } else {
                                          await prefs.setString('userPassword', switchToAccount['password']);
                                          await prefs.remove('accessToken');
                                          await prefs.remove('idToken');
                                        }
                                        await prefs.setBool('isLoggedIn', true);
                                        
                                        // Update linked accounts with fresh tokens if we got them
                                        if (switchToAccount['isGoogleAccount'] == true && googleAuth != null) {
                                          // Find and update the account with fresh tokens in our accounts list
                                          for (var account in updatedAccounts) {
                                            if (account['email'].toString().toLowerCase() == switchToAccount['email'].toString().toLowerCase() &&
                                                account['isGoogleAccount'] == true) {
                                              account['accessToken'] = googleAuth.accessToken;
                                              account['idToken'] = googleAuth.idToken;
                                              break;
                                            }
                                          }
                                        }                                        // Now that authentication is complete, update the UI state
                                        setState(() {
                                          _accounts = updatedAccounts;
                                          _email = user.email ?? switchToAccount['email'];
                                          _username = _email.split('@')[0];
                                        });
                                        
                                        // Save updated linked accounts with any new tokens
                                        await _saveLinkedAccounts();
                                        
                                        // Reload linked accounts to ensure consistency
                                        await _loadLinkedAccounts();
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
                                              Expanded(child: Text('Successfully switched to ${switchToAccount['email']}')),
                                            ],
                                          ),
                                          backgroundColor: Colors.green[600],
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                      
                                      // Use a slightly longer delay before navigation to ensure Firebase Auth has completed its operations
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


