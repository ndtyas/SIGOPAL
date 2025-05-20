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
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Color(0xFF17778F)),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF17778F),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
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
      backgroundColor: const Color(0xFF62C3D0),
      body: Stack(
        children: [
          // 🔵 Background image
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'images/air.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 🔵 Header
                  Row(
                    children: [
                      const Text(
                        "Pengontrolan",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17778F),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Color(0xFF17778F)),
                        onPressed: () => _logout(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 45),

                  // 🔵 Tiga indikator atas
                  Row(
                    children: [
                      buildInfoCard(Icons.water_drop, "9", "Debit Air"),
                      buildInfoCard(Icons.flash_on, "9", "Tegangan"),
                      buildInfoCard(Icons.swap_vert, "9", "Arus"),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 🔵 Kotak putih isi teks dan tombol
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Pencet Tombol Untuk\nBuka Tutup Kran",
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
                                  color: Colors.black.withOpacity(0.3),
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

                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
