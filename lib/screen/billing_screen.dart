import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  DateTime? startDate;
  DateTime? endDate;

  final int meterAwal = 5000;
  final int meterAkhir = 6200;
  final double hargaPerLiter = 0.005;

  String userName = "";

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Pakai displayName jika ada, kalau tidak ada pakai email sebagai fallback
      userName = user.displayName ?? user.email ?? "User";
    } else {
      userName = "User";
    }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/checkauth');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? DateTime.now() : startDate ?? DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = null; // reset endDate jika lebih kecil dari startDate
          }
        } else {
          endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final usage = (meterAkhir - meterAwal).toDouble();
    final cost = usage * hargaPerLiter;

    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: Stack(
        children: [
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
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16),
                  child: Row(
                    children: [
                      const Text(
                        "Tagihan Air",
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
                ),
                const SizedBox(height: 16),

                if (startDate == null || endDate == null)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 40),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 50),
                          child: Image.asset(
                            'images/logoPutih.png',
                            width: 170,
                            height: 170,
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF17778F),
                            minimumSize: const Size(300, 60),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                          onPressed: () => _selectDate(context, true),
                          child: Text(
                            startDate == null
                                ? 'Pilih Tanggal Awal'
                                : 'Awal: ${DateFormat('yyyy-MM-dd').format(startDate!)}',
                          ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF17778F),
                            minimumSize: const Size(300, 60),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                          onPressed: () => _selectDate(context, false),
                          child: Text(
                            endDate == null
                                ? 'Pilih Tanggal Akhir'
                                : 'Akhir: ${DateFormat('yyyy-MM-dd').format(endDate!)}',
                          ),
                        ),
                      ],
                    ),
                  ),

                if (startDate != null && endDate != null)
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(16),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Center(
                                    child: Text(
                                      "TAGIHAN",
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF17778F),
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 30, color: Color(0xFF17778F)),

                                  const SizedBox(height: 25),

                                  // Nama dari Firebase Auth user
                                  Text("Nama : $userName", style: const TextStyle(color: Color(0xFF17778F))),
                                  const SizedBox(height: 10),

                                  Text("Node : ", style: const TextStyle(color: Color(0xFF17778F))),
                                  const SizedBox(height: 20),
                                  const Text("Tanggal Mulai", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF17778F))),
                                  const SizedBox(height: 5),
                                  Text(
                                    startDate != null
                                        ? DateFormat('yyyy-MM-dd').format(startDate!)
                                        : "-",
                                    style: const TextStyle(
                                      color: Color(0xFF17778F),
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 20),
                                  const Text("Tanggal Akhir", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF17778F))),
                                  const SizedBox(height: 5),
                                  Text(
                                    endDate != null
                                        ? DateFormat('yyyy-MM-dd').format(endDate!)
                                        : "-",
                                    style: const TextStyle(
                                      color: Color(0xFF17778F),
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 20),
                                  const Text("Pemakaian", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF17778F))),
                                  const SizedBox(height: 5),
                                  Text(
                                    "${usage.toStringAsFixed(2)} liter x Rp ${hargaPerLiter.toStringAsFixed(3)}",
                                    style: const TextStyle(color: Color(0xFF17778F)),
                                  ),

                                  const SizedBox(height: 20),
                                  const Divider(color: Color(0xFF17778F)),

                                  Text(
                                    "Total Biaya: Rp ${cost.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Color(0xFF17778F),
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF17778F),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () {
                              setState(() {
                                startDate = null;
                                endDate = null;
                              });
                            },
                            child: const Text("Pilih Ulang Tanggal"),
                          ),
                        ),
                      ],
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
