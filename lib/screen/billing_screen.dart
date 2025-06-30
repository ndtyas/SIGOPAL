import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'dart:developer' as developer;


class PrimaryStyledButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? leadingIcon;
  final bool iconOnTop; 

  const PrimaryStyledButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.leadingIcon,
    this.iconOnTop = false, 
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? Colors.white,
        foregroundColor: foregroundColor ?? const Color(0xFF17778F),
        minimumSize: const Size(double.infinity, 80), 
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Color(0xFF17778F),
              ),
            )
          : iconOnTop 
              ? Column( 
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    if (leadingIcon != null) ...[
                      leadingIcon!,
                      const SizedBox(height: 4),
                    ],
                    Flexible(
                      child: Text(
                        text,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              : Row( 
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leadingIcon != null) ...[
                      leadingIcon!,
                      const SizedBox(width: 8), 
                    ],
                    Flexible(
                      child: Text(
                        text,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
    );
  }
}

class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  static const String _meterReadingsPath = 'meter_readings';

  DateTime? startDate;
  DateTime? endDate;

  double meterAwal = 0.0;
  double meterAkhir = 0.0;
  double hargaPerCBM = 2000.0;
  String nodeName = "Memuat...";
  String userName = "Memuat...";
  bool _isLoading = true;

  double _currentUsage = 0.0;
  double _currentTotalCost = 0.0;

  List<Map<String, dynamic>> _billingHistory = [];

  late DatabaseReference _databaseRef;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _loadUserDataAndBilling();
    _loadBillingHistory();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _initializeFirebase() {
    try {
      const String databaseURL = 'https://sigopal-default-rtdb.firebaseio.com';
      _databaseRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: databaseURL,
      ).ref();
      developer.log('Firebase initialized successfully with URL: $databaseURL in BillingScreen', name: 'BillingScreen');
    } catch (e) {
      developer.log('Error initializing Firebase in BillingScreen: $e', name: 'BillingScreen');
      _databaseRef = FirebaseDatabase.instance.ref();
      developer.log('Falling back to default Firebase instance in BillingScreen', name: 'BillingScreen');
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    if (amount == amount.toInt()) {
      return formatter.format(amount.toInt());
    } else {
      return NumberFormat('#,##0.00', 'id_ID').format(amount);
    }
  }

  // Refactored to automatically determine date range and fetch meter readings
  void _loadUserDataAndBilling() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted && userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            userName = data?['username'] ?? user.displayName ?? user.email ?? "Pengguna";
            nodeName = data?['nodeName'] ?? "Node Tidak Ditemukan";
          });
          // Once nodeName is set, fetch meter readings
          if (nodeName != "Memuat..." && !nodeName.contains("Tidak Ditemukan") && !nodeName.contains("Error")) {
            await _determineAndFetchMeterReadings(nodeName);
          }
        } else if (mounted) {
          setState(() {
            userName = user.displayName ?? user.email ?? "Pengguna";
            nodeName = "Node Tidak Ditemukan";
          });
          _showErrorSnackBar("Tidak dapat menemukan data node untuk pengguna ini.");
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            userName = user.displayName ?? user.email ?? "Pengguna";
            nodeName = "Error Mengambil Node";
          });
          _showErrorSnackBar("Error fetching user data from Firestore: $e");
          if (kDebugMode) {
            print("Error fetching user data from Firestore: $e");
          }
        }
      }
    } else {
      if (mounted) {
        setState(() {
          userName = "Pengguna";
          nodeName = "Node Tidak Tersedia";
        });
        _showErrorSnackBar("Pengguna tidak masuk.");
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // New function to determine the date range and fetch readings
  Future<void> _determineAndFetchMeterReadings(String node) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final DataSnapshot snapshot = await _databaseRef
          .child(_meterReadingsPath)
          .child(node)
          .orderByKey()
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> readings = snapshot.value as Map<dynamic, dynamic>;
        if (readings.isNotEmpty) {
          final sortedKeys = readings.keys.cast<String>().toList()..sort();

          // Get the earliest and latest date from the available readings
          startDate = DateFormat('yyyy-MM-dd').parse(sortedKeys.first);
          endDate = DateFormat('yyyy-MM-dd').parse(sortedKeys.last);

          // Fetch the meter readings for this determined period
          await _fetchMeterReadingsForPeriod(startDate!, endDate!);
        } else {
          _showInfoSnackBar("Tidak ada data meteran untuk node ini.");
          if (mounted) {
            setState(() {
              meterAwal = 0.0;
              meterAkhir = 0.0;
              _currentUsage = 0.0;
              _currentTotalCost = 0.0;
            });
          }
        }
      } else {
        _showInfoSnackBar("Tidak ada data meteran ditemukan untuk node ini.");
        if (mounted) {
          setState(() {
            meterAwal = 0.0;
            meterAkhir = 0.0;
            _currentUsage = 0.0;
            _currentTotalCost = 0.0;
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar("Error menentukan rentang tanggal meteran: $e");
      if (kDebugMode) {
        print("Error determining meter reading date range: $e");
      }
      if (mounted) {
        setState(() {
          meterAwal = 0.0;
          meterAkhir = 0.0;
          _currentUsage = 0.0;
          _currentTotalCost = 0.0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<double> _getLatestMeterReadingOnOrBefore(String nodeName, DateTime date) async {
    final String dateStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final DataSnapshot snapshot = await _databaseRef
          .child(_meterReadingsPath)
          .child(nodeName)
          .orderByKey()
          .endAt(dateStr)
          .limitToLast(1)
          .get();

      if (snapshot.exists && snapshot.value != null) {
        final Map<dynamic, dynamic> readings = snapshot.value as Map<dynamic, dynamic>;
        if (readings.isNotEmpty) {
          final latestReadingValue = readings.values.first;
          return (latestReadingValue as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (e) {
      developer.log('Error fetching meter reading for node $nodeName on date $date: $e', name: 'BillingScreen');
    }
    return 0.0;
  }

  Future<void> _fetchMeterReadingsForPeriod(DateTime start, DateTime end) async {
    if (!mounted) return;

    if (nodeName == "Memuat..." || nodeName.contains("Tidak Ditemukan") || nodeName.contains("Error")) {
      _showErrorSnackBar("Tidak dapat mengambil data meteran: $nodeName.");
      return;
    }

    setState(() {
      _isLoading = true;
      meterAwal = 0.0;
      meterAkhir = 0.0;
      _currentUsage = 0.0;
      _currentTotalCost = 0.0;
    });

    try {
      final double startPeriodReading = await _getLatestMeterReadingOnOrBefore(nodeName, start);
      final double endPeriodReading = await _getLatestMeterReadingOnOrBefore(nodeName, end);

      if (mounted) {
        setState(() {
          meterAwal = startPeriodReading;
          meterAkhir = endPeriodReading;
          _currentUsage = (meterAkhir >= meterAwal) ? (meterAkhir - meterAwal) : 0.0;
          _currentTotalCost = _currentUsage * hargaPerCBM;
        });
      }

      if (meterAwal == 0.0 && meterAkhir == 0.0 && mounted) {
        _showInfoSnackBar("Tidak ada data meteran untuk periode yang dipilih.");
      } else if (meterAwal == 0.0 && meterAkhir > 0.0 && mounted) {
        _showInfoSnackBar("Data awal meteran tidak ditemukan. Perhitungan dimulai dari 0.");
      }
    } catch (e) {
      _showErrorSnackBar("Error mengambil data meteran: $e");
      if (kDebugMode) {
        print("Error fetching meter readings from RTDB: $e");
      }
      setState(() {
        meterAwal = 0.0;
        meterAkhir = 0.0;
        _currentUsage = 0.0;
        _currentTotalCost = 0.0;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _saveBillingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || startDate == null || endDate == null) {
      if (mounted) {
        _showErrorSnackBar("Data tidak lengkap untuk disimpan. Pastikan tanggal telah dipilih.");
      }
      return;
    }

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
        'usage': _currentUsage,
        'totalCost': _currentTotalCost,
        'timestamp': FieldValue.serverTimestamp(),
        'docId': docId,
        'nodeName': nodeName,
      });

      if (mounted) {
        _showSuccessSnackBar("Data tagihan berhasil disimpan!");
        _loadBillingHistory();
        // Reset the current display to potentially trigger a re-fetch of current period
        setState(() {
          startDate = null;
          endDate = null;
          meterAwal = 0.0;
          meterAkhir = 0.0;
          _currentUsage = 0.0;
          _currentTotalCost = 0.0;
        });
        _loadUserDataAndBilling(); 
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Gagal menyimpan data tagihan: $e");
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
        setState(() => _billingHistory = []);
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
              .map((doc) => doc.data())
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        if (kDebugMode) {
          print("Error loading billing history: $e");
        }
        setState(() => _billingHistory = []);
      }
    }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/checkauth');
    }
  }

  // Helper for showing snackbars
  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    _showSnackBar(message, const Color(0xFF17778F));
  }

  void _showErrorSnackBar(String message) {
    _showSnackBar(message, Colors.red);
  }

  void _showInfoSnackBar(String message) {
    _showSnackBar(message, Colors.orange);
  }

  Widget _buildDetailRow(String label, String value, {bool isLoading = false}) {
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
          if (isLoading)
            const Text(
              "Memuat...",
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF17778F),
                fontStyle: FontStyle.italic,
              ),
            )
          else
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
    final screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = screenHeight * 0.03;

    return Scaffold(
      body: Container(
        color: const Color(0xFF62C3D0),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, topPadding, 20, 40),
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
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                      onPressed: () {
                        // Reset all and re-fetch to get the latest period
                        setState(() {
                          startDate = null;
                          endDate = null;
                          meterAwal = 0.0;
                          meterAkhir = 0.0;
                          _currentUsage = 0.0;
                          _currentTotalCost = 0.0;
                          _isLoading = false;
                        });
                        _loadUserDataAndBilling();
                      },
                      tooltip: 'Refresh Data',
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                      onPressed: () => _logout(context),
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: const Color(0xF2FFFFFF),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
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
                            const Divider(height: 30, thickness: 1.5, color: Color(0xFF17778F)),
                            _buildDetailRow("Nama", userName, isLoading: _isLoading),
                            _buildDetailRow("Node", nodeName, isLoading: _isLoading),
                            const SizedBox(height: 10),
                            _buildDetailRow(
                              "Tanggal Mulai",
                              startDate == null ? "Memuat..." : DateFormat('dd MMMM y').format(startDate!),
                              isLoading: _isLoading,
                            ),
                            _buildDetailRow(
                              "Tanggal Akhir",
                              endDate == null ? "Memuat..." : DateFormat('dd MMMM y').format(endDate!),
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 10),
                            _buildDetailRow("Meter Awal", "${meterAwal.toStringAsFixed(2)} m\u00B3", isLoading: _isLoading),
                            _buildDetailRow("Meter Akhir", "${meterAkhir.toStringAsFixed(2)} m\u00B3", isLoading: _isLoading),
                            _buildDetailRow("Pemakaian", "${_currentUsage.toStringAsFixed(2)} m\u00B3", isLoading: _isLoading),
                            _buildDetailRow("Harga per m\u00B3", "Rp ${_formatCurrency(hargaPerCBM)}"),
                            const SizedBox(height: 10),
                            const Divider(height: 30, thickness: 1.5, color: Color(0xFF17778F)),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Text(
                                    "Total Biaya: Rp ",
                                    style: TextStyle(
                                      color: Color(0xFF17778F),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_isLoading)
                                    const Text(
                                      "Memuat...",
                                      style: TextStyle(
                                        color: Color(0xFF17778F),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    )
                                  else
                                    Text(
                                      _formatCurrency(_currentTotalCost),
                                      style: const TextStyle(
                                        color: Color(0xFF17778F),
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.0),
                        child: Column(
                          children: [
                            PrimaryStyledButton(
                              onPressed: _saveBillingData,
                              text: "SIMPAN DATA TAGIHAN",
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 10),
                            PrimaryStyledButton(
                              onPressed: () {
                                _loadBillingHistory();
                                _showBillingHistoryDateList(context);
                              },
                              text: "LIHAT RIWAYAT TAGIHAN",
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
      ),
    );
  }

  // --- Dialog Widgets (No significant changes needed, they are already well-structured) ---
  void _showBillingHistoryDateList(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> groupedHistory = {};
    for (var record in _billingHistory) {
      final recordStartDate = (record['startDate'] as Timestamp).toDate();
      final dateKey = DateFormat('dd MMMM y').format(recordStartDate);
      if (!groupedHistory.containsKey(dateKey)) {
        groupedHistory[dateKey] = [];
      }
      groupedHistory[dateKey]!.add(record);
    }

    final sortedDates = groupedHistory.keys.toList()
      ..sort((a, b) => DateFormat('dd MMMM y')
          .parse(b)
          .compareTo(DateFormat('dd MMMM y').parse(a)));

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
                      Navigator.of(context).pop();
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
            "Detail Tagihan\nPeriode: ${DateFormat('dd MMM y').format(recordStartDate)} - ${DateFormat('dd MMM y').format(recordEndDate)}",
            style: const TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("Meter Awal", "${(billingRecord['meterAwal'] as num).toDouble().toStringAsFixed(2)} m\u00B3"),
                _buildDetailRow("Meter Akhir", "${(billingRecord['meterAkhir'] as num).toDouble().toStringAsFixed(2)} m\u00B3"),
                _buildDetailRow("Pemakaian", "${(billingRecord['usage'] as num).toDouble().toStringAsFixed(2)} m\u00B3"),
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
                Navigator.of(context).pop();
                _confirmAndDeleteBillingRecord(context, billingRecord);
              },
            ),
          ],
        );
      },
    );
  }

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
                Navigator.of(context).pop();
                _deleteBillingRecord(billingRecord);
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteBillingRecord(Map<String, dynamic> billingRecord) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        _showErrorSnackBar("Anda perlu masuk untuk menghapus data.");
      }
      return;
    }

    final String? docIdToDelete = billingRecord['docId'] as String?;

    if (docIdToDelete == null || docIdToDelete.isEmpty) {
      if (mounted) {
        _showErrorSnackBar("Gagal menghapus: ID dokumen tidak ditemukan.");
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
        _showSuccessSnackBar("Tagihan berhasil dihapus!");
        _loadBillingHistory();
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Gagal menghapus tagihan: $e");
      }
      if (kDebugMode) {
        print("Error deleting billing data: $e");
      }
    }
  }
}