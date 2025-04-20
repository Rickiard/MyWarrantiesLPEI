import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mywarranties/loading.dart';
import 'firebase_options.dart';
import 'login.dart';
import 'register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'multifunctionsBar.dart';

// Inicialize o GoogleSignIn
final GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId: '598622253789-1oljk3c82dcqorbofvvb2otn12bkkp9s.apps.googleusercontent.com',
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.android,
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<bool> _loadLoginStatus() async {
    // Obtém uma instância do SharedPreferences
    final prefs = await SharedPreferences.getInstance();

    // Verifica se o utilizador está marcado como logado
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (isLoggedIn) {
      // Se o utilizador está marcado como logado, verifica se o token de autenticação existe
      final userPassword = prefs.getString('userPassword');
      final userEmail = prefs.getString('userEmail');
      final userAcessToken = prefs.getString('accessToken');
      final userIdToken = await prefs.getString('idToken');

      if (userPassword != null && userEmail != null) {
        try {
          final AuthCredential credential = EmailAuthProvider.credential(
            email: userEmail,
            password: userPassword,
          );

          // Realiza o login novamente com as credenciais
          await FirebaseAuth.instance.signInWithCredential(credential);

          // Retorna true se o login for bem-sucedido
          return true;
        } catch (e) {
          // Em caso de erro, o token pode estar inválido ou expirado
          // Limpa os dados de login e retorna false
          await prefs.setBool('isLoggedIn', false);
          await prefs.remove('userPassword');
          await prefs.remove('userEmail');
          return false;
        }
      } else if (userAcessToken != null && userIdToken != null) {
        try {
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: userAcessToken,
            idToken: userIdToken,
          );

          // Realiza o login novamente com as credenciais
          await FirebaseAuth.instance.signInWithCredential(credential);

          // Retorna true se o login for bem-sucedido
          return true;
        } catch (e) {
          // Em caso de erro, o token pode estar inválido ou expirado
          // Limpa os dados de login e retorna false
          await prefs.setBool('isLoggedIn', false);
          await prefs.remove('userPassword');
          await prefs.remove('userEmail');
          return false;
        }
      } else {
        await prefs.setBool('isLoggedIn', false);
        return false;
      }
    }

    // Se o utilizador não estiver marcado como logado, retorna false
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loadLoginStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        } else {
          final isLoggedIn = snapshot.data ?? false;
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(primarySwatch: Colors.blue),
            home: isLoggedIn ? LoadingScreen() : WelcomeScreen(),
          );
        }
      },
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  // Função para lidar com o login do Google
  Future<void> _handleGoogleSignIn(BuildContext context) async {
    try {
      // Inicia o processo de login com o Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser != null) {
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
          // Verifique se o utilizador já existe no Firestore
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (!userDoc.exists) {
            // Guardar os dados do utilizador no Firestore se ele for novo
            await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
              'id': user.uid,
              'email': user.email,
              'name': user.displayName,
              'created_at': FieldValue.serverTimestamp(), 
              'update_at': FieldValue.serverTimestamp()
            });
          }

          // Exibe uma mensagem de sucesso
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Login bem-sucedido com ${user.displayName}")),
          );

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('accessToken', googleAuth.accessToken ?? '');
          await prefs.setString('idToken', googleAuth.idToken ?? '');

          // Redirecione para a tela principal ou outra tela após o login
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoadingScreen()),
          );
        }
      }
    } catch (e) {
      // Exibe uma mensagem de erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao fazer login com Google: $e")),
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