import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth_firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:provider/provider.dart';
import 'package:sigopal/provider/auth_provider.dart';

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
  static const String _lastDataPath = 'last_data';

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
  String? _activeNode;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _loadUserDataAndBilling();
    _loadBillingHistory();
    _triggerCheckAndSaveMonthlyBillAfterLoad();
  }

  // A helper to trigger the check after initial data is loaded
  void _triggerCheckAndSaveMonthlyBillAfterLoad() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _checkAndSaveMonthlyBill();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _initializeFirebase() {
    try {
      _databaseRef = FirebaseDatabase.instance.ref();
      developer.log('Firebase initialized successfully in BillingScreen',
          name: 'BillingScreen');
    } catch (e) {
      developer.log('Error initializing Firebase in BillingScreen: $e',
          name: 'BillingScreen');
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'id_ID');
    return formatter.format(amount);
  }

  // Helper function to safely convert dynamic value to double
  double _convertToDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      // Try parsing string as double, default to 0.0 if not a valid number
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  void _loadUserDataAndBilling() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      meterAwal = 0.0;
      meterAkhir = 0.0;
      _currentUsage = 0.0;
      _currentTotalCost = 0.0;
      startDate = null;
      endDate = null;
    });

    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted && userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            userName = data?['username'] ?? user.displayName ?? user.email ?? "Pengguna";
          });

          final auth = Provider.of<AuthProvider>(context, listen: false);
          final retrievedNode = auth.getCurrentNode();
          if (retrievedNode != null) {
            setState(() {
              nodeName = retrievedNode;
              _activeNode = retrievedNode;
            });
            await _calculateMeterReadings(retrievedNode);
          } else {
            setState(() {
              nodeName = "Node Tidak Ditemukan";
              _activeNode = null;
            });
            _showErrorSnackBar(
                "Tidak dapat menemukan node. Harap masukkan node di halaman sebelumnya.");
          }
        } else if (mounted) {
          setState(() {
            userName = user.displayName ?? user.email ?? "Pengguna";
            nodeName = "Node Tidak Ditemukan";
            _activeNode = null;
          });
          _showErrorSnackBar("Tidak dapat menemukan data pengguna ini.");
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            userName = user.displayName ?? user.email ?? "Pengguna";
            nodeName = "Error Mengambil Node";
            _activeNode = null;
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
          _activeNode = null;
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

  Future<void> _calculateMeterReadings(String node) async {
    if (!mounted) return;

    try {
      final now = DateTime.now();
      endDate = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second);
      startDate = DateTime(now.year, now.month, 1);

      // 1. Get current accumulated debit (meterAkhir)
      final DataSnapshot lastDebitSnapshot =
          await _databaseRef.child(_lastDataPath).child(node).child('debit_air').get();

      // Use _convertToDouble to handle various data types safely
      double currentDebit = _convertToDouble(lastDebitSnapshot.value);
      developer.log('Meter Akhir (current debit_air): $currentDebit',
          name: 'BillingScreen');

      // 2. Get previous month's accumulated debit (meterAwal)
      double previousMonthDebit = 0.0;
      final previousMonth = DateTime(now.year, now.month - 1, 1);
      final previousMonthKey = DateFormat('yyyy-MM').format(previousMonth);

      final DataSnapshot previousMonthSnapshot =
          await _databaseRef.child(_lastDataPath).child(node).child(previousMonthKey).get();

      if (previousMonthSnapshot.exists && previousMonthSnapshot.value != null) {
        // Use _convertToDouble to handle various data types safely
        previousMonthDebit = _convertToDouble(previousMonthSnapshot.value);
        developer.log(
            'Meter Awal (from RTDB $previousMonthKey): $previousMonthDebit',
            name: 'BillingScreen');
      } else {
        developer.log(
            'No previous month debit data found for node $node under key $previousMonthKey. Assuming 0.',
            name: 'BillingScreen');
      }

      setState(() {
        meterAwal = previousMonthDebit;
        meterAkhir = currentDebit;
        _currentUsage = meterAkhir - meterAwal;
        if (_currentUsage < 0) _currentUsage = 0.0;
        _currentTotalCost = _currentUsage * hargaPerCBM;
      });
    } catch (e) {
      _showErrorSnackBar("Error menghitung meteran: $e");
      if (kDebugMode) {
        print("Error calculating meter readings: $e");
      }
      if (mounted) {
        setState(() {
          meterAwal = 0.0;
          meterAkhir = 0.0;
          _currentUsage = 0.0;
          _currentTotalCost = 0.0;
          startDate = null;
          endDate = null;
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

  Future<void> _checkAndSaveMonthlyBill() async {
    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user == null || _activeNode == null || startDate == null || endDate == null) {
      developer.log("Skipping _checkAndSaveMonthlyBill: User, node, or date data is null.", name: 'BillingScreen');
      return;
    }

    final now = DateTime.now();
    final currentMonthYearKey = DateFormat('yyyy-MM').format(now);
    
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day; 

    if (now.day == lastDayOfMonth) {
      developer.log('It is the last day of the month (${now.day}/$lastDayOfMonth). Checking for saved bill.', name: 'BillingScreen');
      try {
        final startOfMonthTimestamp = Timestamp.fromDate(DateTime(now.year, now.month, 1, 0, 0, 0));
        final startOfNextMonthTimestamp = Timestamp.fromDate(DateTime(now.year, now.month + 1, 1, 0, 0, 0));

        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('billing_records')
            .where('nodeName', isEqualTo: _activeNode)
            .where('startDate', isGreaterThanOrEqualTo: startOfMonthTimestamp)
            .where('startDate', isLessThan: startOfNextMonthTimestamp)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          developer.log('No existing bill found for $currentMonthYearKey. Auto-saving now.',
              name: 'BillingScreen');
          await _saveBillingDataInternal(
            user.uid,
            _activeNode!,
            startDate!, 
            endDate!,
            meterAwal,
            meterAkhir,
            hargaPerCBM,
            _currentUsage,
            _currentTotalCost,
          );
          if (mounted) {
            _showSuccessSnackBar("Tagihan bulan ini berhasil disimpan otomatis!");
            _loadBillingHistory();
          }
        } else {
          developer.log('Monthly bill for $currentMonthYearKey already saved.',
              name: 'BillingScreen');
        }
      } catch (e) {
        developer.log('Error checking/auto-saving monthly bill: $e',
            name: 'BillingScreen');
        if (mounted) {
          _showErrorSnackBar("Gagal menyimpan tagihan otomatis: $e");
        }
      }
    } else {
      developer.log('Not the last day of the month (${now.day}/$lastDayOfMonth). Skipping auto-save.',
          name: 'BillingScreen');
    }
  }

  Future<void> _saveBillingDataInternal(
      String userId,
      String node,
      DateTime startDt,
      DateTime endDt,
      double mtrAwal,
      double mtrAkhir,
      double hargaCBM,
      double usage,
      double totalCost) async {
    try {
      String docId = DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('billing_records')
          .doc(docId)
          .set({
        'startDate': Timestamp.fromDate(startDt),
        'endDate': Timestamp.fromDate(endDt),
        'meterAwal': mtrAwal,
        'meterAkhir': mtrAkhir,
        'hargaPerCBM': hargaCBM,
        'usage': usage,
        'totalCost': totalCost,
        'timestamp': FieldValue.serverTimestamp(),
        'docId': docId,
        'nodeName': node,
      });

      final monthToSaveKey = DateFormat('yyyy-MM').format(endDt);
      await _databaseRef.child(_lastDataPath).child(node).update({
        monthToSaveKey: mtrAkhir,
      });
      developer.log('Saved meterAkhir ($mtrAkhir) to RTDB at $_lastDataPath/$node/$monthToSaveKey', name: 'BillingScreen');

    } catch (e) {
      if (kDebugMode) {
        print("Error saving billing data internally: $e");
      }
      rethrow;
    }
  }

  void _loadBillingHistory() async {
    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _billingHistory = []);
      }
      return;
    }

    try {
      final now = DateTime.now();
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year + 1, 1, 1);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('billing_records')
          .where('timestamp', isGreaterThanOrEqualTo: startOfYear)
          .where('timestamp', isLessThan: endOfYear)
          .orderBy('timestamp', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _billingHistory = querySnapshot.docs.map((doc) => doc.data()).toList();
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.signOut();
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/checkauth');
    }
  }

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
                      icon: Image.asset(
                        'images/riwayat2.png',
                        width: 28,
                        height: 28,
                        color: Colors.white,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.history,
                            color: Colors.white,
                            size: 28,
                          );
                        },
                      ),
                      onPressed: () {
                        _loadBillingHistory();
                        _showBillingHistoryDateList(context);
                      },
                      tooltip: 'Lihat Riwayat Tagihan',
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                      onPressed: () {
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
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const Divider(
                                height: 30, thickness: 1.5, color: Color(0xFF17778F)),
                            _buildDetailRow("Nama", userName, isLoading: _isLoading),
                            _buildDetailRow("Node", nodeName, isLoading: _isLoading),
                            const SizedBox(height: 10),
                            _buildDetailRow(
                              "Tanggal Mulai",
                              startDate == null
                                  ? "Memuat..."
                                  : DateFormat('dd MMMM y').format(startDate!),
                              isLoading: _isLoading,
                            ),
                            _buildDetailRow(
                              "Tanggal Akhir",
                              endDate == null
                                  ? "Memuat..."
                                  : DateFormat('dd MMMM y').format(endDate!),
                              isLoading: _isLoading,
                            ),
                            const SizedBox(height: 10),
                            _buildDetailRow("Meter Awal", "${meterAwal.toStringAsFixed(4)} m\u00B3",
                                isLoading: _isLoading),
                            _buildDetailRow("Meter Akhir", "${meterAkhir.toStringAsFixed(4)} m\u00B3",
                                isLoading: _isLoading),
                            _buildDetailRow(
                                "Pemakaian", "${_currentUsage.toStringAsFixed(4)} m\u00B3",
                                isLoading: _isLoading),
                            _buildDetailRow("Harga per m\u00B3", "Rp ${_formatCurrency(hargaPerCBM)}"),
                            const SizedBox(height: 10),
                            const Divider(
                                height: 30, thickness: 1.5, color: Color(0xFF17778F)),
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
                      const SizedBox(height: 20),
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

  void _showBillingHistoryDateList(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> groupedHistory = {};
    for (var record in _billingHistory) {
      final recordTimestamp = (record['timestamp'] as Timestamp?)?.toDate();
      if (recordTimestamp == null) continue;

      final recordStartDate = (record['startDate'] as Timestamp).toDate();
      final dateKey = DateFormat('dd MMMM y').format(recordStartDate);
      if (!groupedHistory.containsKey(dateKey)) {
        groupedHistory[dateKey] = [];
      }
      groupedHistory[dateKey]!.add(record);
    }

    final sortedDates = groupedHistory.keys.toList()
      ..sort((a, b) {
        final dateA = DateFormat('dd MMMM y').parse(a);
        final dateB = DateFormat('dd MMMM y').parse(b);
        return dateB.compareTo(dateA);
      });

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xF2FFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Riwayat Tagihan",
              style: TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold)),
          content: _billingHistory.isEmpty
              ? const Text("Belum ada riwayat tagihan untuk tahun ini.",
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
                _buildDetailRow("Meter Awal", "${(billingRecord['meterAwal'] as num).toDouble().toStringAsFixed(4)} m\u00B3"),
                _buildDetailRow("Meter Akhir", "${(billingRecord['meterAkhir'] as num).toDouble().toStringAsFixed(4)} m\u00B3"),
                _buildDetailRow("Pemakaian", "${(billingRecord['usage'] as num).toDouble().toStringAsFixed(4)} m\u00B3"),
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
    final user = auth_firebase.FirebaseAuth.instance.currentUser;
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