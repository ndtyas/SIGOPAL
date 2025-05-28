import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ControllingScreen extends StatefulWidget {
  const ControllingScreen({super.key});

  @override
  State<ControllingScreen> createState() => _ControllingScreenState();
}

class _ControllingScreenState extends State<ControllingScreen> {
  bool valveOpen = false;

  void toggleValve() {
    setState(() {
      valveOpen = !valveOpen;
    });
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/checkauth');
    }
  }

  Widget buildInfoCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xF2FFFFFF), // 95% opacity white (F2 is already an alpha value)
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              // Replaced .withOpacity(0.15) with 0x26 (approx 15% opacity)
              color: const Color(0x26000000), // 0x26 is approx 15% of FF (255)
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: const Color(0xFF17778F)),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF17778F),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF17778F),
              ),
            ),
          ],
        ),
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
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Pengontrolan",
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
                    const SizedBox(height: 40),

                    // Row dibungkus dengan Expanded agar tidak overflow
                    Row(
                      children: [
                        buildInfoCard(Icons.water_drop, "9", "Debit Air"),
                        buildInfoCard(Icons.flash_on, "9", "Tegangan"),
                        buildInfoCard(Icons.swap_vert, "9", "Arus"),
                      ],
                    ),
                    const SizedBox(height: 30),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xF2FFFFFF), // 95% white (F2 is already an alpha value)
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            // Replaced .withOpacity(0.2) with 0x33 (approx 20% opacity)
                            color: const Color(0x33000000), // 0x33 is approx 20% of FF (255)
                            blurRadius: 12,
                            spreadRadius: 3,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            "Ketuk Tombol Untuk\nBuka Tutup Kran",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              color: Color(0xFF17778F),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 25),
                          GestureDetector(
                            onTap: toggleValve,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: valveOpen ? Colors.red : const Color(0xFF17778F),
                                boxShadow: [
                                  BoxShadow(
                                    // Replaced .withOpacity(0.3) with 0x4C (approx 30% opacity)
                                    color: const Color(0x4C000000), // 0x4C is approx 30% of FF (255)
                                    blurRadius: 10,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  valveOpen ? "OFF" : "ON",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20), // Bottom spacing
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