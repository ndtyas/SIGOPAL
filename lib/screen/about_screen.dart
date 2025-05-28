import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: Stack(
        children: [
          // 🔵 Background image with opacity
          Positioned.fill(
            child: Opacity(
              opacity: 0.3,
              child: Image.asset(
                'images/air.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          // 🔵 Main content
          SafeArea(
            child: Column(
              children: [
                // 🔵 Header bar with back button and logos
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Row(
                        children: [
                          Image.asset(
                            'images/logoPutih.png', // ganti dengan nama file logo pertama
                            width: 30,
                            height: 30,
                          ),
                          const SizedBox(width: 10),
                          Image.asset(
                            'images/logoUndip.png', // ganti dengan nama file logo kedua
                            width: 30,
                            height: 30,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 🔵 Body content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'images/tanya.png',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF17778F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: const [
                              Center(
                                child: Text(
                                  "Aplikasi SIGOPAL",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                "SIGOPAL (Sistem Go Optimization Pemantauan Air Lingkungan) merupakan aplikasi inovatif berbasis IoT yang dirancang untuk memantau dan mengelola kualitas air di lingkungan dukuh Agungboyo, terutama pada sumber air artesis dan sungai. "
                                "Melalui sistem filtering dan sensor monitoring yang terhubung, SIGOPAL memantau secara real-time data pengelolaan air. "
                                "Aplikasi ini memberikan solusi pemantauan yang efektif, memungkinkan pengelola lingkungan, pemerintah, dan masyarakat untuk bersama-sama meningkatkan kualitas sumber air secara berkelanjutan.",
                                style: TextStyle(fontSize: 14, color: Colors.white),
                                textAlign: TextAlign.justify,
                              ),
                              SizedBox(height: 20),
                              Center(
                                child: Text(
                                  "Fitur Aplikasi:",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                "• Sign In User:\n"
                                "Pengguna dapat login ke dalam aplikasi SIGOPAL menggunakan akun yang telah terdaftar, dengan perlindungan kata sandi. "
                                "Setiap akun pengguna memiliki otoritas khusus untuk memantau dan mengontrol sumber air artesis di wilayahnya.\n\n"
                                "• Monitoring:\n"
                                "Fitur ini memungkinkan pengguna melihat data kualitas air secara real-time, seperti pH, TDS, turbidity, dan lainnya. "
                                "Level ketinggian water tank juga ditampilkan. Data akan dibandingkan dengan standar baku mutu SNI untuk memudahkan analisa kualitas air.\n\n"
                                "• Controlling:\n"
                                "Pengguna dapat mengontrol perangkat seperti pompa dan selenoid valve secara langsung. Tombol ON/OFF memudahkan pengaturan aliran air tanpa intervensi langsung.\n\n"
                                "• Logout:\n"
                                "Setelah selesai, pengguna dapat keluar dari akun melalui fitur logout untuk memastikan keamanan akses dan mencegah penggunaan tanpa izin.",
                                style: TextStyle(fontSize: 14, color: Colors.white),
                                textAlign: TextAlign.justify,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
