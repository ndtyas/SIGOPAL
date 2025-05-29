import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'provider/auth_provider.dart' as local_auth;
import 'provider/imagepick_provider.dart';

// Import all your application screens
import 'screen/welcome.dart';
import 'screen/about_screen.dart';
import 'screen/login_screen.dart';
import 'screen/home_page.dart'; 
import 'screen/volume_page.dart';
import 'screen/monitoring_screen.dart'; 
import 'screen/controlling_screen.dart';
import 'screen/billing_screen.dart';

void main() async {
  // Ensure Flutter widgets are initialized before Firebase.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with platform-specific options.
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
        // Provide your AuthProvider for authentication state management
        ChangeNotifierProvider(create: (_) => local_auth.AuthProvider()),
        // Provide your ImagePickProvider if used across the app
        ChangeNotifierProvider(create: (_) => ImagePickProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SIGOPAL',
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal, // Keeping your specified seed color
            brightness: Brightness.dark, // Keeping your specified dark brightness
          ),
          // You might want to define other theme properties here for consistency
          // For example, text themes, app bar themes, etc.
          // useMaterial3: true, // You can explicitly enable Material 3 if desired
        ),
        // Define the initial route for the application
        initialRoute: '/welcome',
        // Define all named routes for navigation
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/about': (context) => const AboutPage(),
          '/checkauth': (context) => const AuthWrapper(), // Checks authentication status
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomePage(), // The main screen after successful login
          '/volume': (context) => const VolumePage(),
          '/monitoring': (context) => const MonitoringScreen(), // Route for MonitoringScreen
          '/controlling': (context) => const ControllingScreen(), // Route for ControllingScreen
          '/billing': (context) => const BillingScreen(), // Route for BillingScreen
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to Firebase authentication state changes
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        // Show a loading indicator while the connection to Firebase Auth is waiting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If user is logged in and their email is verified, show the HomePage
        if (snapshot.hasData && snapshot.data!.emailVerified) {
          return const HomePage();
        }

        // Otherwise, if no user is logged in or email is not verified, show the LoginScreen
        return const LoginScreen();
      },
    );
  }
}