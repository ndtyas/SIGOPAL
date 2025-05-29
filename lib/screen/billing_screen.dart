import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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

  String userName = "";
  bool _isLoading = true;

  List<Map<String, dynamic>> _billingHistory = [];

  @override
  void initState() {
    super.initState();
    _loadUserDataAndBilling();
    _loadBillingHistory();
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
          } else {
            userName = user.displayName ?? user.email ?? "Pengguna";
          }
        }
      } catch (e) {
        if (mounted) {
          userName = user.displayName ?? user.email ?? "Pengguna";
          if (kDebugMode) {
            print("Error fetching user data from Firestore: $e");
          }
        }
      }

      try {
        final billingDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('billing_records')
            .doc('current_period')
            .get();

        if (mounted) {
          if (billingDoc.exists) {
            final data = billingDoc.data();
            setState(() {
              meterAwal = data?['meterAwal'] ?? 0;
              meterAkhir = data?['meterAkhir'] ?? 0;
              hargaPerCBM = (data?['hargaPerCBM'] as num?)?.toDouble() ?? 0.0;
            });
          } else {
            setState(() {
              meterAwal = 5000;
              meterAkhir = 6200;
              hargaPerCBM = 2000.0;
            });
            if (kDebugMode) {
              print("No billing data found for user ${user.uid}. Using dummy data.");
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            meterAwal = 5000;
            meterAkhir = 6200;
            hargaPerCBM = 2000.0;
          });
          if (kDebugMode) {
            print("Error fetching billing data from Firestore: $e");
          }
        }
      }
    } else {
      if (mounted) {
        userName = "Pengguna";
        setState(() {
          meterAwal = 5000;
          meterAkhir = 6200;
          hargaPerCBM = 2000.0;
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
      String docId = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

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
          // Setelah simpan, kembali ke halaman pemilihan tanggal
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
                  'images/air.png',
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
                                // Tombol untuk melihat riwayat billing
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
                                    // Tampilkan dialog riwayat
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
                                  _buildDetailRow("Node", "Node A-123"),

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
                                    "${(meterAkhir - meterAwal).toDouble().toStringAsFixed(2)} m\u00B3",
                                  ),
                                  _buildDetailRow(
                                    "Harga per m\u00B3",
                                    "Rp ${NumberFormat('#,##0.00', 'id_ID').format(hargaPerCBM)}",
                                  ),

                                  const SizedBox(height: 10),
                                  const Divider(
                                      height: 30, thickness: 1.5, color: Color(0xFF17778F)),

                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      "Total Biaya: Rp ${NumberFormat('#,##0.00', 'id_ID').format((meterAkhir - meterAwal) * hargaPerCBM)}",
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
                            const SizedBox(height: 30), // Spasi antara kartu dan tombol

                            // Tombol Opsi setelah tanggal dipilih dan data billing ditampilkan
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 0.0), // No horizontal padding here as it's inside SingleChildScrollView
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

  // --- Widget Baru: Dialog Riwayat Billing (Hanya List Tanggal) ---
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
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        elevation: 4,
                        color: const Color(0xFFE0F2F7),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () {
                            // Find the correct record to pass to the detail dialog
                            final recordToDisplay = groupedHistory[date]!.first; // Assuming one record per date for simplicity
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

  // --- Widget Baru: Dialog Detail Billing untuk Tanggal yang Dipilih ---
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
                _buildDetailRow("Pemakaian", "${billingRecord['usage'].toStringAsFixed(2)} m\u00B3"),
                _buildDetailRow("Harga per m\u00B3", "Rp ${NumberFormat('#,##0.00', 'id_ID').format(billingRecord['hargaPerCBM'])}"),
                const Divider(height: 15, thickness: 1, color: Colors.grey),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "Total: Rp ${NumberFormat('#,##0.00', 'id_ID').format(billingRecord['totalCost'])}",
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
          ],
        );
      },
    );
  }
}