import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mywarranties/loading.dart';
import 'package:mywarranties/services/notification_service.dart';
import 'package:mywarranties/services/background_service.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'list.dart';
import 'package:uuid/uuid.dart';

// Inicialize o GoogleSignIn
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: '598622253789-1oljk3c82dcqorbofvvb2otn12bkkp9s.apps.googleusercontent.com',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Enable immersive mode to hide both status bar and navigation bar
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.android,
  );
  
  try {
    // Initialize notification service
    final notificationService = NotificationService();
    await notificationService.init();
    
    // Initialize background service for warranty checks
    await BackgroundService.initialize();
    
    print('Notification and background services initialized successfully');
  } catch (e) {
    print('Error initializing notification services: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _loadLoginStatus() async {
    try {
      // Check if a user is already signed in
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // Verify device token
        final prefs = await SharedPreferences.getInstance();
        final deviceToken = prefs.getString('deviceToken');
        
        if (deviceToken != null) {
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
                
            if (userDoc.exists) {
              final data = userDoc.data();
              if (data?['deviceToken'] != deviceToken) {
                // Device token mismatch - another device has logged in
                await FirebaseAuth.instance.signOut();
                await prefs.setBool('isLoggedIn', false);
                await prefs.remove('userEmail');
                await prefs.remove('userPassword');
                await prefs.remove('accessToken');
                await prefs.remove('idToken');
                await prefs.remove('deviceToken');
                return false;
              }
            }
          } catch (e) {
            print('Error checking device token: $e');
            // If there's an error checking the token, assume the session is valid
            return true;
          }
        }
        
        // User is already signed in and device token matches
        return true;
      }
      
      // Obtém uma instância do SharedPreferences
      final prefs = await SharedPreferences.getInstance();
  
      // Verifica se o utilizador está marcado como logado
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  
      if (isLoggedIn) {
        // Se o utilizador está marcado como logado, verifica se o token de autenticação existe
        final userPassword = prefs.getString('userPassword');
        final userEmail = prefs.getString('userEmail');
        final userAcessToken = prefs.getString('accessToken');
        final userIdToken = prefs.getString('idToken');
        final deviceToken = prefs.getString('deviceToken');
  
        if (userPassword != null && userEmail != null) {
          try {
            // Sign out any existing user first to ensure clean state
            await FirebaseAuth.instance.signOut();
            
            // Realiza o login com as credenciais de email/password
            final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: userEmail,
              password: userPassword,
            );
            
            // Verify device token after login
            if (deviceToken != null && userCredential.user != null) {
              try {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userCredential.user!.uid)
                    .get();
                    
                if (userDoc.exists) {
                  final data = userDoc.data();
                  if (data?['deviceToken'] != deviceToken) {
                    // Device token mismatch - another device has logged in
                    await FirebaseAuth.instance.signOut();
                    await prefs.setBool('isLoggedIn', false);
                    await prefs.remove('userEmail');
                    await prefs.remove('userPassword');
                    await prefs.remove('accessToken');
                    await prefs.remove('idToken');
                    await prefs.remove('deviceToken');
                    return false;
                  }
                }
              } catch (e) {
                print('Error checking device token after login: $e');
                // If there's an error checking the token, assume the session is valid
                return true;
              }
            }
  
            // Retorna true se o login for bem-sucedido
            return true;
          } catch (e) {
            print('Error signing in with email/password: $e');
            // Em caso de erro, o token pode estar inválido ou expirado
            // Limpa os dados de login e retorna false
            await prefs.setBool('isLoggedIn', false);
            await prefs.remove('userPassword');
            await prefs.remove('userEmail');
            await prefs.remove('deviceToken');
            return false;
          }
        } else if (userAcessToken != null && userIdToken != null) {
          try {
            // Sign out any existing user first to ensure clean state
            await FirebaseAuth.instance.signOut();
            
            final AuthCredential credential = GoogleAuthProvider.credential(
              accessToken: userAcessToken,
              idToken: userIdToken,
            );
  
            // Realiza o login novamente com as credenciais
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            
            // Verify device token after login
            if (deviceToken != null && userCredential.user != null) {
              try {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(userCredential.user!.uid)
                    .get();
                    
                if (userDoc.exists) {
                  final data = userDoc.data();
                  if (data?['deviceToken'] != deviceToken) {
                    // Device token mismatch - another device has logged in
                    await FirebaseAuth.instance.signOut();
                    await prefs.setBool('isLoggedIn', false);
                    await prefs.remove('userEmail');
                    await prefs.remove('userPassword');
                    await prefs.remove('accessToken');
                    await prefs.remove('idToken');
                    await prefs.remove('deviceToken');
                    return false;
                  }
                }
              } catch (e) {
                print('Error checking device token after Google login: $e');
                // If there's an error checking the token, assume the session is valid
                return true;
              }
            }
  
            // Retorna true se o login for bem-sucedido
            return true;
          } catch (e) {
            print('Error signing in with Google: $e');
            // Em caso de erro, o token pode estar inválido ou expirado
            // Limpa os dados de login e retorna false
            await prefs.setBool('isLoggedIn', false);
            await prefs.remove('accessToken');
            await prefs.remove('idToken');
            await prefs.remove('deviceToken');
            return false;
          }
        }
      }
  
      // Se o utilizador não estiver marcado como logado, retorna false
      return false;
    } catch (e) {
      print('Unexpected error in _loadLoginStatus: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loadLoginStatus(),
      builder: (context, snapshot) {
        // Always show the MaterialApp with consistent theme
        final MaterialApp app = MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(primarySwatch: Colors.blue),
          home: _buildHomeScreen(snapshot),
        );
        
        return app;
      },
    );
  }
  
  Widget _buildHomeScreen(AsyncSnapshot<bool> snapshot) {
    // Handle different states of the authentication process
    if (snapshot.connectionState == ConnectionState.waiting) {
      return LoadingScreen();
    } else if (snapshot.hasError) {
      print('Error in authentication: ${snapshot.error}');
      // If there's an error, show the welcome screen
      return WelcomeScreen();
    } else {
      final isLoggedIn = snapshot.data ?? false;
      return isLoggedIn ? ListPage() : WelcomeScreen();
    }
  }
}

class WelcomeScreen extends StatelessWidget {
  // Função para lidar com o login do Google
  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Inicia o processo de login com o Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
        try {
          // Obtenha os detalhes da conta do Google
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

          // Crie uma credencial do Firebase com o token do Google
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          // Faça login no Firebase usando a credencial do Google
          final UserCredential userCredential =
              await FirebaseAuth.instance.signInWithCredential(credential);

          final User? user = userCredential.user;

          if (user != null) {
            try {
              // Generate device token
              final deviceToken = Uuid().v4();

              // Check for existing session
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get();

              if (userDoc.exists) {
                final data = userDoc.data();
                if (data?['isLoggedIn'] == true && data?['deviceToken'] != null) {
                  // Send notification to the other device
                  await FirebaseFirestore.instance
                      .collection('notifications')
                      .doc(user.uid)
                      .set({
                    'message': 'You have been logged out because your account was accessed on another device.',
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  // Update the user's document to clear the previous session
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .update({
                    'isLoggedIn': false,
                    'deviceToken': null,
                  });
                }
              }

              // Update user document with new session
              await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                'id': user.uid,
                'email': user.email,
                'name': user.displayName,
                'created_at': FieldValue.serverTimestamp(),
                'update_at': FieldValue.serverTimestamp(),
                'isLoggedIn': true,
                'deviceToken': deviceToken,
                'lastLogin': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));

              // Save session information
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isLoggedIn', true);
              await prefs.setString('accessToken', googleAuth.accessToken ?? '');
              await prefs.setString('idToken', googleAuth.idToken ?? '');
              await prefs.setString('deviceToken', deviceToken);

              // Close loading dialog
              if (Navigator.canPop(context)) {
                Navigator.of(context, rootNavigator: true).pop();
              }

              // Exibe uma mensagem de sucesso
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 10),
                      Expanded(child: Text("Welcome back, ${user.displayName}!")),
                    ],
                  ),
                  backgroundColor: Colors.green[600],
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );

              // Redirecione para a tela principal
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
          print('Error during Google sign in: $e');
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
                  Expanded(child: Text("Error signing in with Google. Please try again.")),
                ],
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: Duration(seconds: 4),
            ),
          );
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
              Expanded(child: Text("Error signing in with Google. Please try again.")),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFADD8E6), // Azul bebê
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo da App com Imagem Completa
              Image.asset(
                'assets/AppLogo.png',
                width: 150,
                height: 150,
              ),

              SizedBox(height: 30),

              // Texto "MyWarranties" com Tipografia Melhorada
              Text(
                'MyWarranties',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 1.2,
                ),
              ),

              SizedBox(height: 15),

              // Texto descritivo com estilo refinado
              Text(
                'Manage Your Product Warranties – Never Lose a Thing!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),

              SizedBox(height: 40),

              // Botão "Start Now" com Design Moderno e Cor Adequada
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => RegisterScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green, // Cor verde para o botão "Start Now"
                  foregroundColor: Colors.white, // Cor do texto
                  elevation: 3,
                  padding: EdgeInsets.symmetric(horizontal: 50, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Start Now',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Botão "Sign in with Google" com altura igual aos outros botões
              InkWell(
                onTap: () => _handleGoogleSignIn(context),
                child: Container(
                  height: 56, // Altura fixa para corresponder aos outros botões
                  width: 292,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30), // Borda arredondada
                    border: Border.all(color: Colors.grey.shade300, width: 1), // Borda cinza
                    color: Colors.white, // Fundo branco
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1), // Sombra sutil
                        spreadRadius: 2,
                        blurRadius: 5,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20), // Preenchimento horizontal
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, // Centraliza o conteúdo
                      children: [
                        Image.asset(
                          'assets/google_logo.png', // Caminho da imagem do Google
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 20),

              // Botão "Login With Email"
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.black, width: 1.5),
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  'Login With Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
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