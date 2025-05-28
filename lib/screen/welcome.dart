import 'package:flutter/material.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: Stack(
        children: [
          // Gambar latar belakang dengan opacity
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'images/air.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Konten utama
          SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 0),
                  Image.asset(
                    'images/logoText.png',
                    width: 250,
                    height: 250,
                  ),

                  const SizedBox(height: 35),

                  // Tombol "Tentang Kami"
                  SizedBox(
                    width: 200,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/about');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF17778F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      child: const Text(
                        'Tentang Kami',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Tombol "Masuk"
                  SizedBox(
                    width: 200,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/checkauth');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF17778F),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      child: const Text(
                        'Masuk',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
