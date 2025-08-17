import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart'; 

import 'firebase_options.dart';
import 'provider/auth_provider.dart' as local_auth;
import 'provider/imagepick_provider.dart';
import 'notification_service.dart';

import 'screen/welcome.dart';
import 'screen/about_screen.dart';
import 'screen/login_screen.dart';
import 'screen/home_page.dart';
import 'screen/volume_page.dart';
import 'screen/monitoring_screen.dart';
import 'screen/controlling_screen.dart';
import 'screen/billing_screen.dart';
import 'screen/node_screen.dart';
import 'screen/admin/admin_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await initializeDateFormatting('id_ID', null);
  NotificationService.initialize();

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
        theme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.dark,
          ),
        ),
        initialRoute: '/welcome',
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/about': (context) => const AboutPage(),
          '/checkauth': (context) => const AuthWrapper(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomePage(),
          '/volume': (context) => const VolumePage(),
          '/monitoring': (context) => const MonitoringScreen(),
          '/controlling': (context) => const ControllingScreen(),
          '/billing': (context) => const BillingScreen(),
          '/node_screen': (context) => const NodeScreen(),
          '/admin_home': (context) => const AdminNavigation(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<local_auth.AuthProvider>(context);
    
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data!.emailVerified) {
          if (!authProvider.isUserInitialized) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (authProvider.isAdmin) {
            return const AdminNavigation();
          } else {
            return const NodeScreen();
          }
        }

        return const LoginScreen();
      },
    );
  }
}