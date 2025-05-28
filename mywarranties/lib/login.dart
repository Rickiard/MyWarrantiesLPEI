import 'package:flutter/material.dart';
import 'package:mywarranties/list.dart';
import 'package:mywarranties/passwordRecovery.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  final _uuid = Uuid();

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  Future<String> _generateDeviceToken() async {
    return _uuid.v4();
  }

  Future<bool> _checkExistingSession(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['isLoggedIn'] == true && data?['deviceToken'] != null;
      }
      return false;
    } catch (e) {
      print('Error checking existing session: $e');
      return false;
    }
  }

  Future<void> _handleExistingSession(String userId) async {
    try {
      // Send notification to the other device
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .set({
        'message': 'You have been logged out because your account was accessed on another device.',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update the user's document to clear the previous session
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({
        'isLoggedIn': false,
        'deviceToken': null,
      });
    } catch (e) {
      print('Error handling existing session: $e');
      // Continue with login even if notification fails
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFADD8E6), // Azul bebê claro
      body: SafeArea(
        child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centraliza verticalmente
            crossAxisAlignment: CrossAxisAlignment.center, // Centraliza horizontalmente
            children: [
              // Ícone de voltar
              Align(
                alignment: Alignment.topLeft,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 25,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),

              SizedBox(height: 30),

              // Logo da App centralizado
              Image.asset(
                'assets/AppLogo.png', // Substitua pelo caminho da imagem do logo da app
                width: 150,
                height: 150,
              ),

              SizedBox(height: 30),

              // Título "Login in Your Account"
              Text(
                'Login in Your Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              SizedBox(height: 40),

              // Formulário de Login
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Campo de Email
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    // Campo de Senha
                    TextField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _isPasswordVisible
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: _togglePasswordVisibility,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    Align(
                      alignment: Alignment.centerLeft,
                      child: RichText(
                        text: TextSpan(
                          text: 'Forgot your password? ',
                          style: TextStyle(
                            color: Colors.black, // Cor do texto normal
                            fontSize: 14,
                          ),
                          children: [
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => PasswordRecoveryScreen()),
                                  );
                                },
                                child: Text(
                                  "Click Here",
                                  style: TextStyle(
                                    color: Colors.blue, // Cor do link
                                    decoration: TextDecoration.underline, // Sublinhado para indicar link
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 30),

                    // Botão "Enter"
                    ElevatedButton(
                      onPressed: () async {
                        final email = _emailController.text.trim();
                        final password = _passwordController.text.trim();

                        if (email.isEmpty || password.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white),
                                  SizedBox(width: 10),
                                  Expanded(child: Text("Please enter your email and password to continue")),
                                ],
                              ),
                              backgroundColor: Colors.blue[700],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          return;
                        }

                        try {
                          // Generate a unique device token
                          final deviceToken = await _generateDeviceToken();

                          // Authenticate the user with Firebase
                          UserCredential userCredential = await FirebaseAuth.instance
                              .signInWithEmailAndPassword(email: email, password: password);

                          final User? user = userCredential.user;

                          if (user != null) {
                            try {
                              // Check for existing session
                              final hasExistingSession = await _checkExistingSession(user.uid);
                              
                              if (hasExistingSession) {
                                // Handle existing session
                                await _handleExistingSession(user.uid);
                              }

                              // Update the user's document with the new session
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .set({
                                'isLoggedIn': true,
                                'deviceToken': deviceToken,
                                'lastLogin': FieldValue.serverTimestamp(),
                              }, SetOptions(merge: true));

                              // Save session information to SharedPreferences
                              SharedPreferences prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('isLoggedIn', true);
                              await prefs.setString('userEmail', user.email ?? '');
                              await prefs.setString('userPassword', password);
                              await prefs.setString('deviceToken', deviceToken);

                              // Close loading dialog
                              if (Navigator.canPop(context)) {
                                Navigator.of(context, rootNavigator: true).pop();
                              }

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 10),
                                      Expanded(child: Text("Welcome back, ${user.email}!")),
                                    ],
                                  ),
                                  backgroundColor: Colors.green[600],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );

                              // Navigate to the main screen
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => ListPage()),
                              );
                            } catch (e) {
                              print('Error updating session: $e');
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
                                      Expanded(child: Text("Error updating session. Please try again.")),
                                    ],
                                  ),
                                  backgroundColor: Colors.red[700],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          // Handle error messages
                          String errorMessage = "Unable to sign in. Please check your credentials and try again.";
                          if (e is FirebaseAuthException) {
                            switch (e.code) {
                              case 'user-not-found':
                                errorMessage = "No account found with this email. Please check or create a new account.";
                                break;
                              case 'wrong-password':
                                errorMessage = "Incorrect password. Please try again or reset your password.";
                                break;
                              case 'invalid-email':
                                errorMessage = "Please enter a valid email address.";
                                break;
                              case 'user-disabled':
                                errorMessage = "This account has been disabled. Please contact support.";
                                break;
                              case 'too-many-requests':
                                errorMessage = "Too many sign-in attempts. Please try again later.";
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
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Enter',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}