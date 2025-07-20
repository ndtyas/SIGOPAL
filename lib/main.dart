import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';

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
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runZonedGuarded<Future<void>>(() async {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await initializeDateFormatting('id_ID', null);
    NotificationService.initialize();

    runApp(const MyApp());
  }, (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  });
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
        // Gunakan custom performance observer
        navigatorObservers: [
          CustomPerformanceObserver(),
        ],
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
          return const NodeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

// Custom Performance Observer (jika diperlukan)
class CustomPerformanceObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null) {
      // Log navigasi untuk performance monitoring
      FirebasePerformance.instance.newTrace('screen_${route.settings.name}').start();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route.settings.name != null) {
      // Stop trace saat keluar dari screen
      FirebasePerformance.instance.newTrace('screen_${route.settings.name}').stop();
    }
  }
}