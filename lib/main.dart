import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'provider/auth_provider.dart' as local_auth;
import 'provider/imagepick_provider.dart';
import 'screen/login_screen.dart';
import 'screen/welcome.dart';
import 'screen/home_page.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => local_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_) => ImagePickProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SIGOPAL',
        darkTheme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.green,
            brightness: Brightness.dark,
          ),
        ),
        themeMode: ThemeMode.dark,
        initialRoute: '/',
        routes: {
          '/checkauth': (context) => const AuthWrapper(),
          '/': (context) => const WelcomeScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data!.emailVerified) {
          return const HomePage(); // ← arahkan ke halaman dengan bottom nav
        } else if (snapshot.hasData && !snapshot.data!.emailVerified) {
          return const LoginScreen(); // jika belum verifikasi
        }
        return const LoginScreen();
      },
    );
  }
}
