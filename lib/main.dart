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

void main() async {
  // Pastikan widget Flutter diinisialisasi sebelum Firebase.
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // PERBAIKAN: Tambahkan baris ini untuk memuat data format tanggal Indonesia
  await initializeDateFormatting('id_ID', null);

  // Inisialisasi layanan notifikasi
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
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<firebase_auth.User?>(
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data!.emailVerified) {
          // Arahkan ke NodeScreen untuk verifikasi node
          return const NodeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}