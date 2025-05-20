import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: GestureDetector(
        onTap: () {
          // Navigasi ke halaman login atau auth wrapper
          Navigator.pushReplacementNamed(context, '/checkauth');
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView( // Menghindari overflow
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'images/logo.png',
                    width: MediaQuery.of(context).size.width * 0.99, // Responsif
                    height: MediaQuery.of(context).size.height * 0.77, // Responsif
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
