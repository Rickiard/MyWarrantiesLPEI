import 'package:flutter/material.dart';
import 'package:mywarranties/list.dart';
import 'package:mywarranties/passwordRecovery.dart';
import 'loading.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFADD8E6), // Azul bebê claro
      body: SingleChildScrollView(
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
                      onPressed: () async{
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
                          // Autenticar o utilizador com Firebase
                          UserCredential userCredential = await FirebaseAuth.instance
                              .signInWithEmailAndPassword(email: email, password: password);

                          final User? user = userCredential.user;

                          if (user != null) {
                            // Check if this account is already logged in on another device
                            DocumentSnapshot userDoc = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .get();
                            
                            if (userDoc.exists && userDoc.data() != null) {
                              Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
                              
                              if (userData['isLoggedIn'] == true && userData['deviceId'] != null) {
                                String previousDeviceId = userData['deviceId'];
                                
                                if (previousDeviceId.isNotEmpty) {
                                  // Create a logout notification for the previous device
                                  await FirebaseFirestore.instance
                                      .collection('forceLogout')
                                      .doc(user.uid)
                                      .set({
                                    'deviceId': previousDeviceId,
                                    'message': 'You have been logged out because your account was accessed on another device.',
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'forceLogout': true
                                  });
                                  
                                  print('Sent logout notification to previous device: $previousDeviceId');
                                }
                              }
                            }
                            
                            // Generate a unique device ID for this device
                            String deviceId = DateTime.now().millisecondsSinceEpoch.toString() + '_' + user.uid;
                            
                            // Update login status for current device
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .set({
                              'isLoggedIn': true,
                              'deviceId': deviceId,
                              'lastLoginTime': FieldValue.serverTimestamp()
                            }, SetOptions(merge: true));

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

                            SharedPreferences prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('isLoggedIn', true);
                            await prefs.setString('userEmail', user.email ?? '');
                            await prefs.setString('userPassword', password);

                            // Redirecionar para a tela principal ou outra tela
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => ListPage()),
                            );
                          }
                        } catch (e) {
                          // Exibir mensagem de erro
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}