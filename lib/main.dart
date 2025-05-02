import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'provider/auth_provider.dart' as local_auth;
import 'provider/imagepick_provider.dart';
import 'screen/home_screen.dart';
import 'screen/login_screen.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_)=> local_auth.AuthProvider()),
        ChangeNotifierProvider(create: (_)=> ImagePickProvider())
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Flutter Demo',
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          primarySwatch: Colors.green
        ),
        themeMode: ThemeMode.dark,
        home: StreamBuilder(
          stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
          builder: (ctx,snapshot){
            if(snapshot.hasData){
              return const HomePage();
            }
            return const LoginScreen();
          })
       
      ),
    );
  }
}
