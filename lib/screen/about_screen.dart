import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Header bar dengan tombol kembali dan logo
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
                            'images/logoPutih.png',
                            width: 30,
                            height: 30,
                          ),
                          const SizedBox(width: 10),
                          Image.asset(
                            'images/logoUndip.png',
                            width: 30,
                            height: 30,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Konten utama
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
                        // Kotak Definisi Aplikasi SIGOPAL
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
                                  "Tentang Aplikasi SIGOPAL",
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
                                "SIGOPAL (Sistem Go Optimization Pemantauan Air Lingkungan) adalah sebuah aplikasi mobile inovatif berbasis Internet of Things (IoT) yang dirancang sebagai solusi strategis untuk mengatasi tantangan pengelolaan air PAMSIMAS, khususnya di Dukuh Kragilan. Aplikasi ini mengintegrasikan sistem sensor dengan platform mobile untuk memberikan akses data kualitas dan ketersediaan air secara real-time kepada masyarakat.",
                                style: TextStyle(fontSize: 14, color: Colors.white),
                                textAlign: TextAlign.justify,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'images/jawaban.png',
                              width: 200,
                              height: 200,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Kotak Fitur Aplikasi
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF17778F),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Center(
                                child: Text(
                                  "Fitur Aplikasi",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              SizedBox(height: 15),
                              _FeatureText(
                                title: "Pemantauan Kualitas dan Debit Air",
                                description:
                                    "Fitur pemantauan memungkinkan Anda melihat data kualitas air secara langsung. Anda dapat memantau debit air, kadar TDS, dan tingkat pH air. Untuk menjamin keamanan, semua parameter dibandingkan dengan Standar Nasional Indonesia (SNI) sebagai acuan.",
                              ),
                              _FeatureText(
                                title: "Pemantauan Ketinggian Air Tandon",
                                description:
                                    "Jangan pernah lagi kehabisan air secara tak terduga. Fitur ini memungkinkan Anda memeriksa volume air yang tersisa di tandon. Sistem akan menampilkan status level air secara visual, membantu Anda mengelola persediaan air dengan lebih efisien.",
                              ),
                              _FeatureText(
                                title: "Pengawasan Status Sistem Alat",
                                description:
                                    "SIGOPAL dapat memeriksa status operasional kran node dan pompa tandon. Kran dapat terlihat sedang dalam mode terbuka atau tertutup. Begitupun juga pompa yang dapat dipantau statusnya on, off, mati listrik, atau rusak.",
                              ),
                              _FeatureText(
                                title: "Tagihan Air yang Transparan",
                                description:
                                    "Fitur tagihan air menyajikan rincian pemakaian Anda setiap bulan dengan jelas. Mulai dari catatan meter awal dan akhir, total pemakaian, hingga harga per m³. Anda tahu persis apa yang Anda bayar, tanpa biaya tersembunyi.",
                              ),
                              _FeatureText(
                                title: "Riwayat Tagihan Perbulan",
                                description:
                                    "Kelola keuangan Anda lebih baik dengan arsip tagihan bulanan yang dapat diakses kapan saja. Halaman ringkasan memberikan gambaran cepat mengenai status total tagihan, yang sudah dibayar, belum dibayar, dan yang terlambat.",
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

/// Widget bantuan untuk menampilkan judul dan deskripsi fitur
class _FeatureText extends StatelessWidget {
  final String title;
  final String description;

  const _FeatureText({
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(fontSize: 14, color: Colors.white),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }
}
