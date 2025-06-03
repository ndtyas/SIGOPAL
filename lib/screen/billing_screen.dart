import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// You would define your API service here, e.g.:
// class ApiService {
//   final String _baseUrl = "YOUR_GATEWAY_API_BASE_URL";

//   Future<Map<String, dynamic>> fetchMeterData(
//       String userId, DateTime startDate, DateTime endDate) async {
//     // This is a placeholder. Replace with your actual API endpoint and logic.
//     final response = await http.get(Uri.parse(
//         '$_baseUrl/meter_readings?userId=$userId&startDate=${startDate.toIso8601String()}&endDate=${endDate.toIso8601String()}'));

//     if (response.statusCode == 200) {
//       return json.decode(response.body);
//     } else {
//       throw Exception('Failed to load meter data from gateway');
//     }
//   }

//   // You might also fetch hargaPerCBM from API if it's dynamic
//   // Future<double> fetchHargaPerCBM() async {
//   //   final response = await http.get(Uri.parse('$_baseUrl/price_config'));
//   //   if (response.statusCode == 200) {
//   //     final data = json.decode(response.body);
//   //     return (data['hargaPerCBM'] as num).toDouble();
//   //   } else {
//   //     throw Exception('Failed to load price config');
//   //   }
//   // }
// }

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  DateTime? startDate;
  DateTime? endDate;

  int meterAwal = 0;
  int meterAkhir = 0;
  double hargaPerCBM = 0.0;
  String nodeName = "Memuat..."; // New state for node name

  String userName = "";
  bool _isLoading = true;

  List<Map<String, dynamic>> _billingHistory = [];

  // final ApiService _apiService = ApiService(); // Initialize your API service

  @override
  void initState() {
    super.initState();
    _loadUserDataAndBilling();
    _loadBillingHistory();
  }

  // Helper to format currency without .00 if it's a whole number
  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    if (amount == amount.toInt()) {
      return formatter.format(amount.toInt());
    } else {
      return NumberFormat('#,##0.00', 'id_ID').format(amount);
    }
  }

  void _loadUserDataAndBilling() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted) {
          if (userDoc.exists) {
            userName = userDoc.data()?['username'] ?? user.displayName ?? user.email ?? "Pengguna";
            // Assuming nodeName might be part of user data in Firestore or fetched from API
            nodeName = userDoc.data()?['nodeName'] ?? "Node A-123";
          } else {
            userName = user.displayName ?? user.email ?? "Pengguna";
            nodeName = "Node A-123"; // Default if no user doc
          }
        }
      } catch (e) {
        if (mounted) {
          userName = user.displayName ?? user.email ?? "Pengguna";
          nodeName = "Node A-123"; // Fallback
          if (kDebugMode) {
            print("Error fetching user data from Firestore: $e");
          }
        }
      }

      // --- Integration point for API: Fetch initial meter and price data ---
      try {
        // This is where you would call your API service
        // Example:
        // final meterData = await _apiService.fetchMeterData(user.uid, DateTime.now().subtract(const Duration(days: 30)), DateTime.now());
        // setState(() {
        //   meterAwal = meterData['startMeter'] ?? 0;
        //   meterAkhir = meterData['endMeter'] ?? 0;
        //   hargaPerCBM = (meterData['pricePerCBM'] as num?)?.toDouble() ?? 0.0;
        //   nodeName = meterData['node'] ?? "N/A"; // Assuming node data is also in API response
        // });

        // For now, using existing Firestore logic for 'current_period' dummy data
        final billingDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('billing_records')
            .doc('current_period') // This is largely for dummy data.
            .get();

        if (mounted) {
          if (billingDoc.exists) {
            final data = billingDoc.data();
            setState(() {
              meterAwal = data?['meterAwal'] ?? 0;
              meterAkhir = data?['meterAkhir'] ?? 0;
              hargaPerCBM = (data?['hargaPerCBM'] as num?)?.toDouble() ?? 0.0;
              // If nodeName is not from userDoc, you could try to get it from billingDoc
              nodeName = data?['nodeName'] ?? "Node A-123";
            });
          } else {
            setState(() {
              // Dummy data for initial display if no 'current_period' document
              meterAwal = 5000;
              meterAkhir = 6200;
              hargaPerCBM = 2000.0;
              nodeName = "Node A-123"; // Default dummy node
            });
            if (kDebugMode) {
              print("No billing data found for user ${user.uid}. Using dummy data.");
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            // Fallback dummy data on error
            meterAwal = 5000;
            meterAkhir = 6200;
            hargaPerCBM = 2000.0;
            nodeName = "Node A-123"; // Fallback dummy node
          });
          if (kDebugMode) {
            print("Error fetching billing data (from Firestore or API): $e");
          }
        }
      }
    } else {
      if (mounted) {
        userName = "Pengguna";
        setState(() {
          // Dummy data for unauthenticated users
          meterAwal = 5000;
          meterAkhir = 6200;
          hargaPerCBM = 2000.0;
          nodeName = "Node A-123"; // Default dummy node
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _saveBillingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || startDate == null || endDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data tidak lengkap untuk disimpan. Pastikan tanggal telah dipilih."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final usage = (meterAkhir - meterAwal).toDouble();
    final cost = usage * hargaPerCBM;

    try {
      String docId = DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('billing_records')
          .doc(docId)
          .set({
        'startDate': Timestamp.fromDate(startDate!),
        'endDate': Timestamp.fromDate(endDate!),
        'meterAwal': meterAwal,
        'meterAkhir': meterAkhir,
        'hargaPerCBM': hargaPerCBM,
        'usage': usage,
        'totalCost': cost,
        'timestamp': FieldValue.serverTimestamp(),
        'docId': docId,
        'nodeName': nodeName, // Save node name with the billing record
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Data tagihan berhasil disimpan!"),
            backgroundColor: Color(0xFF17778F),
          ),
        );
        _loadBillingHistory();
        setState(() {
          startDate = null;
          endDate = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyimpan data tagihan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (kDebugMode) {
        print("Error saving billing data: $e");
      }
    }
  }

  void _loadBillingHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _billingHistory = [];
        });
      }
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('billing_records')
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _billingHistory = querySnapshot.docs
              .where((doc) => doc.id != 'current_period')
              .map((doc) => doc.data())
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        if (kDebugMode) {
          print("Error loading billing history: $e");
        }
        setState(() {
          _billingHistory = [];
        });
      }
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
      initialDate: DateTime.now(),
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF17778F),
              onPrimary: Colors.white,
              onSurface: Color(0xFF17778F),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF17778F),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      if (mounted) {
        setState(() {
          if (isStart) {
            startDate = picked;
            if (endDate != null && endDate!.isBefore(startDate!)) {
              endDate = null;
            }
          } else {
            if (startDate != null && picked.isBefore(startDate!)) {
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
        // --- Integration point for API: Fetch meter readings based on selected dates ---
        // if (startDate != null && endDate != null) {
        //   final user = FirebaseAuth.instance.currentUser;
        //   if (user != null) {
        //     try {
        //       setState(() { _isLoading = true; });
        //       final meterData = await _apiService.fetchMeterData(user.uid, startDate!, endDate!);
        //       setState(() {
        //         meterAwal = meterData['startMeter'] ?? 0;
        //         meterAkhir = meterData['endMeter'] ?? 0;
        //         // You might need to refetch hargaPerCBM if it's dynamic
        //         // hargaPerCBM = (meterData['pricePerCBM'] as num?)?.toDouble() ?? 0.0;
        //         nodeName = meterData['node'] ?? nodeName; // Update node name if provided by API
        //       });
        //     } catch (e) {
        //       if (mounted) {
        //         ScaffoldMessenger.of(context).showSnackBar(
        //           SnackBar(content: Text("Gagal memuat data meter dari API: $e"), backgroundColor: Colors.red),
        //         );
        //       }
        //       if (kDebugMode) {
        //         print("Error fetching meter data from API: $e");
        //       }
        //       // Fallback or clear meter readings on API error
        //       setState(() {
        //         meterAwal = 0;
        //         meterAkhir = 0;
        //       });
        //     } finally {
        //       setState(() { _isLoading = false; });
        //     }
        //   }
        // }
      }
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
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF17778F),
          ),
        ),
      );
    }

    final usage = (meterAkhir - meterAwal).toDouble();
    final totalCost = usage * hargaPerCBM;

    return Scaffold(
      body: Container(
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
            Positioned.fill(
              child: Opacity(
                opacity: 0.2,
                child: Image.asset(
                  'images/air.png', // Ensure this image exists in your assets
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20),
                    child: Row(
                      children: [
                        const Text(
                          "Tagihan Air",
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
                  ),
                  const SizedBox(height: 16),

                  // Conditional rendering:
                  // Show date selection/history options if dates are not picked
                  // Show billing details if dates are picked
                  if (startDate == null || endDate == null)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 50),
                            child: Image.asset(
                              'images/date2.png',
                              width: 200,
                              height: 200,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Column(
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF17778F), // Standardized color
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 60),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    textStyle: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  onPressed: () => _selectDate(context, true),
                                  child: Text(
                                    startDate == null
                                        ? 'PILIH TANGGAL AWAL'
                                        : 'Awal: ${DateFormat('dd MMMM yyyy').format(startDate!)}',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF17778F), // Standardized color
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 60),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    textStyle: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  onPressed: () => _selectDate(context, false),
                                  child: Text(
                                    endDate == null
                                        ? 'PILIH TANGGAL AKHIR'
                                        : 'Akhir: ${DateFormat('dd MMMM yyyy').format(endDate!)}',
                                  ),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        const Color(0xFF17778F), // Standardized color
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 60),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    textStyle: const TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.bold),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  onPressed: () {
                                    // Show history dialog
                                    _showBillingHistoryDateList(context);
                                  },
                                  child: const Text("LIHAT RIWAYAT TAGIHAN"),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    // This is the billing details page, now fully scrollable
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xF2FFFFFF), // 95% opacity white
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000), // 20% opacity black
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
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
                                  const Divider(
                                      height: 30, thickness: 1.5, color: Color(0xFF17778F)),

                                  _buildDetailRow("Nama", userName),
                                  _buildDetailRow("Node", nodeName),

                                  const SizedBox(height: 10),

                                  _buildDetailRow("Tanggal Mulai",
                                      DateFormat('dd MMMM yyyy').format(startDate!)),
                                  _buildDetailRow("Tanggal Akhir",
                                      DateFormat('dd MMMM yyyy').format(endDate!)),
                                  const SizedBox(height: 10),

                                  _buildDetailRow(
                                    "Meter Awal",
                                    "$meterAwal m\u00B3",
                                  ),
                                  _buildDetailRow(
                                    "Meter Akhir",
                                    "$meterAkhir m\u00B3",
                                  ),
                                  _buildDetailRow(
                                    "Pemakaian",
                                    "${usage.toStringAsFixed(2)} m\u00B3",
                                  ),
                                  _buildDetailRow(
                                    "Harga per m\u00B3",
                                    "Rp ${_formatCurrency(hargaPerCBM)}",
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(
                                      height: 30, thickness: 1.5, color: Color(0xFF17778F)),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "Total Biaya: Rp ${_formatCurrency(totalCost)}",
                                      style: const TextStyle(
                                        color: Color(0xFF17778F),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30), // Space between card and buttons

                            // Option buttons after dates are selected and billing data is shown
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 0.0),
                              child: Column(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF17778F),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      if (mounted) {
                                        setState(() {
                                          startDate = null;
                                          endDate = null;
                                        });
                                      }
                                    },
                                    child: const Text("PILIH ULANG TANGGAL"),
                                  ),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF17778F),
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 50),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: _saveBillingData,
                                    child: const Text("SIMPAN DATA TAGIHAN"),
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
      ),
    );
  }

  // --- New Widget: Billing History List Dialog (Shows only dates) ---
  void _showBillingHistoryDateList(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> groupedHistory = {};
    for (var record in _billingHistory) {
      final recordStartDate = (record['startDate'] as Timestamp).toDate();
      final dateKey = DateFormat('dd MMMM yyyy').format(recordStartDate);
      if (!groupedHistory.containsKey(dateKey)) {
        groupedHistory[dateKey] = [];
      }
      groupedHistory[dateKey]!.add(record);
    }

    final sortedDates = groupedHistory.keys.toList()
      ..sort((a, b) => DateFormat('dd MMMM yyyy')
          .parse(b)
          .compareTo(DateFormat('dd MMMM yyyy').parse(a)));

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xF2FFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Riwayat Tagihan",
              style: TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold)),
          content: _billingHistory.isEmpty
              ? const Text("Belum ada riwayat tagihan.",
                  style: TextStyle(color: Colors.grey))
              : SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: sortedDates.length,
                    itemBuilder: (context, dateIndex) {
                      final date = sortedDates[dateIndex];
                      final recordToDisplay = groupedHistory[date]!.first;
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 4,
                        color: const Color(0xFFE0F2F7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).pop(); // Close date list dialog
                            _showBillingDetailDialog(context, recordToDisplay);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              "Periode Mulai: $date",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF17778F),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
          actions: <Widget>[
            TextButton(
              child: const Text("Tutup", style: TextStyle(color: Color(0xFF17778F))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --- New Widget: Billing Detail Dialog for Selected Date ---
  void _showBillingDetailDialog(BuildContext context, Map<String, dynamic> billingRecord) {
    final recordStartDate = (billingRecord['startDate'] as Timestamp).toDate();
    final recordEndDate = (billingRecord['endDate'] as Timestamp).toDate();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xF2FFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Detail Tagihan\nPeriode: ${DateFormat('dd MMM yyyy').format(recordStartDate)} - ${DateFormat('dd MMM yyyy').format(recordEndDate)}",
            style: const TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("Meter Awal", "${billingRecord['meterAwal']} m\u00B3"),
                _buildDetailRow("Meter Akhir", "${billingRecord['meterAkhir']} m\u00B3"),
                _buildDetailRow("Pemakaian", "${(billingRecord['usage'] as double).toStringAsFixed(2)} m\u00B3"),
                _buildDetailRow("Harga per m\u00B3", "Rp ${_formatCurrency((billingRecord['hargaPerCBM'] as num).toDouble())}"),
                const Divider(height: 15, thickness: 1, color: Colors.grey),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Total: Rp ${_formatCurrency((billingRecord['totalCost'] as num).toDouble())}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF17778F),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Tutup", style: TextStyle(color: Color(0xFF17778F))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Hapus", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Close the detail dialog first
                _confirmAndDeleteBillingRecord(context, billingRecord);
              },
            ),
          ],
        );
      },
    );
  }

  // --- New Function: Confirm and Delete Billing Record ---
  void _confirmAndDeleteBillingRecord(BuildContext context, Map<String, dynamic> billingRecord) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xF2FFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Konfirmasi Hapus",
              style: TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold)),
          content: const Text("Apakah Anda yakin ingin menghapus tagihan ini?",
              style: TextStyle(color: Color(0xFF17778F))),
          actions: <Widget>[
            TextButton(
              child: const Text("Batal", style: TextStyle(color: Color(0xFF17778F))),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text("Hapus", style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop(); // Close confirmation dialog
                _deleteBillingRecord(billingRecord);
              },
            ),
          ],
        );
      },
    );
  }

  // --- New Function: Delete Billing Record from Firestore ---
  void _deleteBillingRecord(Map<String, dynamic> billingRecord) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Anda perlu masuk untuk menghapus data."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final String? docIdToDelete = billingRecord['docId'] as String?;

    if (docIdToDelete == null || docIdToDelete.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal menghapus: ID dokumen tidak ditemukan."),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (kDebugMode) {
        print("Error: docId not found in billingRecord for deletion.");
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('billing_records')
          .doc(docIdToDelete)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Tagihan berhasil dihapus!"),
            backgroundColor: Color(0xFF17778F),
          ),
        );
        _loadBillingHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus tagihan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (kDebugMode) {
        print("Error deleting billing data: $e");
      }
    }
  }
}