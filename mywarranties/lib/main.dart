import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mywarranties/loading.dart';
import 'package:mywarranties/services/notification_service.dart';
import 'package:mywarranties/services/background_service.dart';
import 'package:mywarranties/services/connectivity_service.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'list.dart';
import 'package:uuid/uuid.dart';

// Inicialize o GoogleSignIn com configuração melhorada
final GoogleSignIn _googleSignIn = GoogleSignIn(
  // Usar configuração do Firebase Options para maior segurança
  clientId: '598622253789-1oljk3c82dcqorbofvvb2otn12bkkp9s.apps.googleusercontent.com',
  scopes: [
    'email',
    'https://www.googleapis.com/auth/userinfo.profile',
  ],
  // Adicionar configuração para forçar seleção de conta
  forceCodeForRefreshToken: true,
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
    // Initialize connectivity service
    await ConnectivityService().initialize();
    
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
  // Generate unique device token
  Future<String> _generateDeviceToken() async {
    return Uuid().v4();
  }

  // Check for existing session
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

  // Handle existing session notification
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
  // Validate Google Play Services availability
  Future<bool> _isGooglePlayServicesAvailable() async {
    try {
      // Try to check if Google Sign-In is available
      await _googleSignIn.signOut();
      return true;
    } catch (e) {
      print('Google Play Services not available: $e');
      return false;
    }
  }  // Helper method to safely close loading dialog
  void _closeLoadingDialog(BuildContext context, bool isLoading) {
    if (isLoading) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  // Função para lidar com o login do Google
  Future<void> _handleGoogleSignIn(BuildContext context) async {
    // Show proper loading dialog with Material Design
    bool isLoading = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent back button dismissal
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text("Signing in with Google...")),
            ],
          ),
        ),
      ),
    );

    try {
      // Check if Google Play Services is available
      print('Starting Google Sign-In process...');
      
      // Validate Google Play Services availability
      final bool isAvailable = await _isGooglePlayServicesAvailable();
      if (!isAvailable) {
        _closeLoadingDialog(context, isLoading);
        isLoading = false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text("Google Play Services not available on this device")),
              ],
            ),
            backgroundColor: Colors.orange[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 4),
          ),
        );
        return;      }
      
      // Clear any existing sign-in state
      await _googleSignIn.signOut();
      
      // Inicia o processo de login com o Google com timeout
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn()
          .timeout(Duration(seconds: 30), onTimeout: () {
        throw Exception('Google Sign-In timeout. Please check your connection and try again.');
      });
      
      print('Google Sign-In result: ${googleUser != null ? 'Success' : 'Cancelled or failed'}');

      if (googleUser != null) {
        try {
          print('Getting authentication details for: ${googleUser.email}');          // Obtenha os detalhes da conta do Google com timeout
          final GoogleSignInAuthentication googleAuth = await googleUser.authentication
              .timeout(Duration(seconds: 15), onTimeout: () {
            throw Exception('Google authentication timeout. Please try again.');
          });

          // Check if tokens are valid
          if (googleAuth.accessToken == null || 
              googleAuth.idToken == null ||
              googleAuth.accessToken!.isEmpty ||
              googleAuth.idToken!.isEmpty) {
            throw Exception('Failed to obtain valid Google authentication tokens');
          }

          // Crie uma credencial do Firebase com o token do Google
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );          // Faça login no Firebase usando a credencial do Google com timeout
          final UserCredential userCredential = await FirebaseAuth.instance
              .signInWithCredential(credential)
              .timeout(Duration(seconds: 20), onTimeout: () {
            throw Exception('Firebase authentication timeout. Please try again.');
          });

          final User? user = userCredential.user;

          if (user != null) {
            try {
              // Generate device token
              final deviceToken = await _generateDeviceToken();

              // Check for existing session
              final hasExistingSession = await _checkExistingSession(user.uid);
              
              if (hasExistingSession) {
                // Handle existing session
                await _handleExistingSession(user.uid);
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
              await prefs.setString('idToken', googleAuth.idToken ?? '');              await prefs.setString('deviceToken', deviceToken);

              // Close loading dialog safely
              _closeLoadingDialog(context, isLoading);
              isLoading = false;
              // Wait a bit to ensure dialog is closed
              await Future.delayed(Duration(milliseconds: 200));
              // Close any remaining dialogs at root navigator
              while (Navigator.of(context, rootNavigator: true).canPop()) {
                Navigator.of(context, rootNavigator: true).pop();
                await Future.delayed(Duration(milliseconds: 100));
              }
              // Small delay for UI stability
              await Future.delayed(Duration(milliseconds: 100));

               // Use pushAndRemoveUntil for proper navigation
               if (context.mounted) {
                 Navigator.pushAndRemoveUntil(
                   context,
                   MaterialPageRoute(builder: (context) => ListPage()),
                   (route) => false,
                 );
               }
            } catch (e) {
              print('Error updating session: $e');
              _closeLoadingDialog(context, isLoading);
              isLoading = false;
              
              // Show specific error message
              String errorMessage = "Error updating session. Please try again.";
              if (e.toString().contains('network')) {
                errorMessage = "Network error. Please check your connection and try again.";
              } else if (e.toString().contains('permission')) {
                errorMessage = "Permission denied. Please check your account settings.";
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
              );            }
          }
        } catch (e) {
          print('Error during Google sign in: $e');
          _closeLoadingDialog(context, isLoading);
          isLoading = false;
          
          // Handle specific Google Sign-In errors
          String errorMessage = "Error signing in with Google. Please try again.";
          if (e.toString().contains('timeout')) {
            errorMessage = "Sign-in timeout. Please check your connection and try again.";
          } else if (e.toString().contains('network')) {
            errorMessage = "Network error. Please check your connection.";
          } else if (e.toString().contains('credential')) {
            errorMessage = "Invalid credentials. Please try signing in again.";
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
      } else {
        // User cancelled the sign-in
        _closeLoadingDialog(context, isLoading);
        isLoading = false;
        await Future.delayed(Duration(milliseconds: 200));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text("Sign-in cancelled")),
              ],
            ),
            backgroundColor: Colors.blue[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error initiating Google sign in: $e');
      _closeLoadingDialog(context, isLoading);
      isLoading = false;
      await Future.delayed(Duration(milliseconds: 200));
      
      // Handle general errors
      String errorMessage = "Unable to sign in with Google. Please try again.";
      if (e.toString().contains('timeout')) {
        errorMessage = "Connection timeout. Please check your internet and try again.";
      } else if (e.toString().contains('Google Play Services')) {
        errorMessage = "Google Play Services not available. Please update Google Play Services.";
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