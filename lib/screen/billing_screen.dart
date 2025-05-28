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

  // Dummy data, replace with actual data from backend
  final int meterAwal = 5000;
  final int meterAkhir = 6200;
  final double hargaPerCBM = 2000.0; // Corrected to be a double and represent 2.000 as 2000.0

  String userName = "";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userName = user.displayName ?? user.email ?? "Pengguna"; // Fallback to "Pengguna"
    } else {
      userName = "Pengguna";
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
      initialDate: DateTime.now(), // Always start with today for initialDate
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF17778F), // Header background color
              onPrimary: Colors.white, // Header text color
              onSurface: Color(0xFF17778F), // Body text color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF17778F), // Button text color
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          startDate = picked;
          // If startDate is set and is after current endDate, reset endDate
          if (endDate != null && endDate!.isBefore(startDate!)) {
            endDate = null;
          }
        } else {
          // Ensure endDate is not before startDate if startDate exists
          if (startDate != null && picked.isBefore(startDate!)) {
            // Optionally show a SnackBar or dialog if endDate is invalid
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Tanggal akhir tidak boleh sebelum tanggal awal."),
                backgroundColor: Color(0xFF17778F),
              ),
            );
            return;
          }
          endDate = picked;
        }
      });
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF17778F),
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF17778F),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usage = (meterAkhir - meterAwal).toDouble();
    final cost = usage * hargaPerCBM;

    return Scaffold(
      body: Container(
        // Consistent Gradient Background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF62C3D0), // Lighter blue
              Color(0xFF17778F), // Darker blue
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background image with consistent opacity
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
              child: Column(
                children: [
                  // Consistent Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20), // Increased padding
                    child: Row(
                      children: [
                        const Text(
                          "Tagihan Air",
                          style: TextStyle(
                            fontSize: 24, // Consistent font size
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Consistent color
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white, size: 28), // Consistent icon style
                          onPressed: () => _logout(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Conditional rendering based on date selection
                  if (startDate == null || endDate == null)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 50),
                            child: Image.asset(
                              'images/date2.png',
                              width: 270,
                              height: 270,
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF17778F),
                              foregroundColor: Colors.white, // Text color
                              minimumSize: const Size(300, 60),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15), // Rounded corners
                              ),
                            ),
                            onPressed: () => _selectDate(context, true),
                            child: Text(
                              startDate == null
                                  ? 'PILIH TANGGAL AWAL'
                                  : 'Awal: ${DateFormat('dd MMMM yyyy').format(startDate!)}', // Formatted date
                            ),
                          ),
                          const SizedBox(height: 20), // Adjusted spacing
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF17778F),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(300, 60),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: () => _selectDate(context, false),
                            child: Text(
                              endDate == null
                                  ? 'PILIH TANGGAL AKHIR'
                                  : 'Akhir: ${DateFormat('dd MMMM yyyy').format(endDate!)}', // Formatted date
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (startDate != null && endDate != null)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20), // Consistent padding
                        child: Container(
                          padding: const EdgeInsets.all(24), // Increased inner padding
                          decoration: BoxDecoration(
                            // Replaced Colors.white.withOpacity(0.95) with 0xF2FFFFFF
                            color: const Color(0xF2FFFFFF), // F2 is approx 95% opacity white
                            borderRadius: BorderRadius.circular(20), // Rounded corners
                            boxShadow: [
                              BoxShadow(
                                // Replaced Colors.black.withOpacity(0.2) with 0x33000000
                                color: const Color(0x33000000), // 0x33 is approx 20% opacity black
                                blurRadius: 15,
                                spreadRadius: 3,
                                offset: const Offset(0, 8),
                              ),
                            ],
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
                              const Divider(height: 30, thickness: 1.5, color: Color(0xFF17778F)), // Thicker divider

                              _buildDetailRow("Nama", userName),
                              _buildDetailRow("Node", "Node A-123"), // Placeholder
                              const SizedBox(height: 20),

                              _buildDetailRow("Tanggal Mulai", DateFormat('dd MMMM yyyy').format(startDate!)),
                              _buildDetailRow("Tanggal Akhir", DateFormat('dd MMMM yyyy').format(endDate!)),
                              const SizedBox(height: 20),

                              _buildDetailRow(
                                "Meter Awal",
                                "$meterAwal " + "m\u00B3", // Using Unicode for m³
                              ),
                              _buildDetailRow(
                                "Meter Akhir",
                                "$meterAkhir " + "m\u00B3",
                              ),
                              _buildDetailRow(
                                "Pemakaian",
                                "${usage.toStringAsFixed(2)} " + "m\u00B3",
                              ),
                              _buildDetailRow(
                                "Harga per m\u00B3",
                                "Rp ${NumberFormat('#,##0.00', 'id_ID').format(hargaPerCBM)}", // Formatted currency
                              ),

                              const SizedBox(height: 20),
                              const Divider(height: 30, thickness: 1.5, color: Color(0xFF17778F)),

                              Align(
                                alignment: Alignment.centerRight, // Align total cost to right
                                child: Text(
                                  "Total Biaya: Rp ${NumberFormat('#,##0.00', 'id_ID').format(cost)}", // Formatted currency
                                  style: const TextStyle(
                                    color: Color(0xFF17778F),
                                    fontSize: 20, // Larger total cost
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (startDate != null && endDate != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0), // Consistent padding
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF17778F),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50), // Full width button
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          setState(() {
                            startDate = null;
                            endDate = null;
                          });
                        },
                        child: const Text("PILIH ULANG TANGGAL"),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}