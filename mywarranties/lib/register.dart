import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'package:email_validator/email_validator.dart';

void main() async{

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.android,
  );

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
      home: RegisterScreen(),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _repeatPasswordController = TextEditingController(); 
  bool _isPasswordVisible = false;
  bool _isRepeatPasswordVisible = false;
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

              SizedBox(height: 20),

              // Logo da App centralizado
              Image.asset(
                'assets/AppLogo.png',
                width: 100,
                height: 100,
              ),

              SizedBox(height: 20),

              // Título "Create Your Account"
              Text(
                'Create Your Account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),

              SizedBox(height: 30),

              // Formulário de Registo
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

                    SizedBox(height: 15),

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
                        onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      ),
                    ),

                    SizedBox(height: 15),

                    // Campo de Repetir Senha
                    TextField(
                      controller: _repeatPasswordController,
                      obscureText: !_isRepeatPasswordVisible,
                      decoration: InputDecoration(
                      labelText: 'Repeat Password',
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                        _isRepeatPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
                        ),
                        onPressed: () {
                        setState(() {
                          _isRepeatPasswordVisible = !_isRepeatPasswordVisible;
                        });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      ),
                    ),

                    SizedBox(height: 30),

                    // Botão "Create"
                    ElevatedButton(
                      onPressed: () async {
                        final email = _emailController.text.trim();
                        final password = _passwordController.text.trim();
                        final repeatPassword = _repeatPasswordController.text.trim();

                        if (email.isEmpty || password.isEmpty || repeatPassword.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white),
                                  SizedBox(width: 10),
                                  Expanded(child: Text("Please fill in all required fields to create your account")),
                                ],
                              ),
                              backgroundColor: Colors.blue[700],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          return;
                        }

                        if (!EmailValidator.validate(email)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white),
                                  SizedBox(width: 10),
                                  Expanded(child: Text("Please enter a valid email address (e.g., name@example.com)")),
                                ],
                              ),
                              backgroundColor: Colors.blue[700],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          return;
                        }

                        if (password != repeatPassword) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.white),
                                  SizedBox(width: 10),
                                  Expanded(child: Text("Passwords don't match. Please make sure both passwords are identical")),
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
                          // Criar conta no Firebase
                          UserCredential userCredential = await FirebaseAuth.instance
                              .createUserWithEmailAndPassword(email: email, password: password);

                          final User? user = userCredential.user;

                          if (user != null) {
                            // Guardar informações do utilizador no Firestore
                            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                              'id': user.uid,
                              'email': user.email,
                              'name': '',
                              'created_at': FieldValue.serverTimestamp(),
                              'updated_at': FieldValue.serverTimestamp(),
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 10),
                                    Expanded(child: Text("Account created successfully! Welcome to MyWarranties")),
                                  ],
                                ),
                                backgroundColor: Colors.green[600],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );

                            // Redirecionar para a tela principal ou de login
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => LoginScreen()),
                            );
                          }
                        } catch (e) {
                          // Exibir mensagem de erro
                          // Extract a more user-friendly error message
                          String errorMessage = "Unable to create account. Please try again later.";
                          if (e is FirebaseAuthException) {
                            switch (e.code) {
                              case 'email-already-in-use':
                                errorMessage = "This email is already in use. Please try a different email or sign in.";
                                break;
                              case 'weak-password':
                                errorMessage = "Password is too weak. Please use a stronger password.";
                                break;
                              case 'invalid-email':
                                errorMessage = "Please enter a valid email address.";
                                break;
                              case 'operation-not-allowed':
                                errorMessage = "Account creation is currently disabled. Please try again later.";
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
                        'Create',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}