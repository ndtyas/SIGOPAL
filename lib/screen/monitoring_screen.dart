import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MonitoringScreen extends StatelessWidget {
  const MonitoringScreen({super.key});

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/checkauth');
    }
  }

  Widget dataBox(String imagePath, String value, String title) {
    return Container(
      // Further reduced vertical padding slightly
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Reduced from 12 to 10
      decoration: BoxDecoration(
        // Replaced .withOpacity(0.9) with 0xE6 (90% opacity)
        color: const Color(0xE617778F), // E6 is approx 90% of FF (255)
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 3,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            imagePath,
            width: 50,
            height: 50,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 6), 
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget sniBox() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // Replaced .withOpacity(0.9) with 0xE6 (90% opacity)
        color: const Color(0xE617778F), // E6 is approx 90% of FF (255)
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 3,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Image.asset(
            'images/sni.png',
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Standar SNI",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    SizedBox(
                        width: 40,
                        child: Text("TDS",
                            style: TextStyle(fontSize: 17, color: Colors.white))),
                    Text(": 1000",
                        style: TextStyle(fontSize: 17, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: const [
                    SizedBox(
                        width: 40,
                        child: Text("pH",
                            style: TextStyle(fontSize: 17, color: Colors.white))),
                    Text(": 6 - 9",
                        style: TextStyle(fontSize: 17, color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF62C3D0),
              Color(0xFF17778F),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: Image.asset(
                  'images/air.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header ---
                    Row(
                      children: [
                        const Text(
                          "Pemantauan",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                          onPressed: () => _logout(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // --- Data Monitoring Grid ---
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.0, // Should be fine, but can adjust if needed
                      children: [
                        dataBox("images/tds.png", "150", "Kadar TDS"),
                        dataBox("images/ph.png", "7", "Kadar pH"),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // --- SNI Box ---
                    sniBox(),

                    const SizedBox(height: 15),

                    // --- Circular "Cek Volume Air" Button ---
                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/volume');
                        },
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            // Replaced .withOpacity(0.9) with 0xE6 (90% opacity)
                            color: const Color(0xE617778F), // E6 is approx 90% of FF (255)
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              "Cek\nVolume Air",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}