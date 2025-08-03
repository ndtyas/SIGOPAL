import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth_firebase;
import 'package:cloud_firestore/cloud_firestore.dart';
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
        minimumSize: const Size(double.infinity, 50),
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

  // State untuk UI
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

  /// State untuk melacak apakah tagihan bulan lalu terlewat dan proses penyimpanannya.
  bool _isPreviousMonthBillMissing = false;
  bool _isSavingPreviousMonthBill = false;
  bool _isSavingCurrentBill = false;

  // State untuk data
  List<Map<String, dynamic>> _billingHistory = [];
  late DatabaseReference _databaseRef;
  String? _activeNode;

  @override
  void initState() {
    super.initState();
    Intl.defaultLocale = 'id_ID';
    _initializeFirebase();
  }

  void _initializeFirebase() {
    try {
      _databaseRef = FirebaseDatabase.instance.ref();
      developer.log('Firebase initialized successfully', name: 'BillingScreen');
    } catch (e) {
      developer.log('Error initializing Firebase: $e', name: 'BillingScreen');
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      _showErrorSnackBar(messenger, "Pengguna tidak masuk.");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;

      if (userDoc.exists) {
        final data = userDoc.data();
        final retrievedNode = authProvider.getCurrentNode();

        developer.log("Loading data for node: $retrievedNode", name: "BillingScreen");

        setState(() {
          userName = data?['username'] ?? "Pengguna";
          nodeName = retrievedNode ?? "Node Tidak Ditemukan";
          _activeNode = retrievedNode;
          _isPreviousMonthBillMissing = false;
        });

        if (retrievedNode != null) {
          await _checkIfPreviousMonthBillIsMissing(user.uid, retrievedNode);
          await _calculateCurrentMonthBill(retrievedNode);
          await _loadBillingHistory();
        } else {
          _showErrorSnackBar(messenger, "Node tidak ditemukan. Harap pilih node terlebih dahulu.");
        }
      } else {
        _showErrorSnackBar(messenger, "Data pengguna tidak ditemukan.");
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(messenger, "Terjadi kesalahan saat memuat data: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkIfPreviousMonthBillIsMissing(String userId, String node) async {
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final startOfPreviousMonth = DateTime(previousMonth.year, previousMonth.month, 1);
    final endOfPreviousMonth = DateTime(now.year, now.month, 0, 23, 59, 59);

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('billing_records')
          .where('nodeName', isEqualTo: node)
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPreviousMonth))
          .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfPreviousMonth))
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isPreviousMonthBillMissing = querySnapshot.docs.isEmpty;
        });
      }
    } catch (e) {
      developer.log("Error checking previous month's bill: $e", name: "BillingScreen");
      if (mounted) setState(() => _isPreviousMonthBillMissing = false);
    }
  }

  Future<void> _manualSavePreviousMonthBill() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (_activeNode == null) {
      _showErrorSnackBar(messenger, "Node tidak aktif, tidak bisa menyimpan.");
      return;
    }
    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar(messenger, "Pengguna tidak login.");
      return;
    }

    setState(() => _isSavingPreviousMonthBill = true);

    final String node = _activeNode!;
    final now = DateTime.now();
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final startOfPreviousMonth = DateTime(previousMonth.year, previousMonth.month, 1);
    final endOfPreviousMonth = DateTime(now.year, now.month, 0, 23, 59, 59);

    try {
      // Ambil data bulan lalu dari Realtime Database
      final previousMonthKey = DateFormat('yyyy-MM').format(previousMonth);
      final previousMonthSnapshot = await _databaseRef.child(_lastDataPath).child(node).child(previousMonthKey).get();

      if (!mounted) return;
      if (!previousMonthSnapshot.exists || previousMonthSnapshot.value == null) {
        _showErrorSnackBar(messenger, "Gagal menyimpan: Data meteran bulan lalu tidak ditemukan.");
        setState(() => _isSavingPreviousMonthBill = false);
        return;
      }
      final meterAkhirBulanLalu = _convertToDouble(previousMonthSnapshot.value);

      // Ambil data 2 bulan yang lalu untuk meter awal
      final twoMonthsAgo = DateTime(previousMonth.year, previousMonth.month - 1, 1);
      final twoMonthsAgoKey = DateFormat('yyyy-MM').format(twoMonthsAgo);
      final twoMonthsAgoSnapshot = await _databaseRef.child(_lastDataPath).child(node).child(twoMonthsAgoKey).get();
      
      if (!mounted) return;
      final meterAwalBulanLalu = _convertToDouble(twoMonthsAgoSnapshot.value);

      final usageBulanLalu = meterAkhirBulanLalu - meterAwalBulanLalu;
      final costBulanLalu = (usageBulanLalu > 0 ? usageBulanLalu : 0) * hargaPerCBM;

      // Simpan ke Firestore
      await _saveBillingData(
        userId: user.uid,
        node: node,
        startDate: startOfPreviousMonth,
        endDate: endOfPreviousMonth,
        meterAwal: meterAwalBulanLalu,
        meterAkhir: meterAkhirBulanLalu,
        usage: usageBulanLalu > 0 ? usageBulanLalu : 0,
        totalCost: costBulanLalu,
      );

      if (!mounted) return;
      _showSuccessSnackBar(messenger, "Tagihan bulan lalu berhasil disimpan!");
      await _loadInitialData();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(messenger, "Gagal menyimpan tagihan bulan lalu: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingPreviousMonthBill = false);
      }
    }
  }

  Future<void> _saveCurrentMonthBill() async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    if (_activeNode == null) {
      _showErrorSnackBar(messenger, "Node tidak aktif, tidak bisa menyimpan.");
      return;
    }
    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar(messenger, "Pengguna tidak login.");
      return;
    }

    setState(() => _isSavingCurrentBill = true);

    final String node = _activeNode!;
    final now = DateTime.now();
    final startOfCurrentMonth = DateTime(now.year, now.month, 1);
    final endOfCurrentMonth = now;

    try {
      // Simpan ke Firestore
      await _saveBillingData(
        userId: user.uid,
        node: node,
        startDate: startOfCurrentMonth,
        endDate: endOfCurrentMonth,
        meterAwal: meterAwal,
        meterAkhir: meterAkhir,
        usage: _currentUsage,
        totalCost: _currentTotalCost,
      );

      // Simpan meter akhir ke Realtime Database untuk referensi bulan berikutnya
      final currentMonthKey = DateFormat('yyyy-MM').format(startOfCurrentMonth);
      await _databaseRef.child(_lastDataPath).child(node).update({ 
        currentMonthKey: meterAkhir.toStringAsFixed(3) 
      });

      if (!mounted) return;
      _showSuccessSnackBar(messenger, "Tagihan bulan ini berhasil disimpan!");
      await _loadInitialData();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(messenger, "Gagal menyimpan tagihan bulan ini: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingCurrentBill = false);
      }
    }
  }

  Future<void> _saveBillingData({
    required String userId,
    required String node,
    required DateTime startDate,
    required DateTime endDate,
    required double meterAwal,
    required double meterAkhir,
    required double usage,
    required double totalCost,
  }) async {
    try {
      // Generate document ID dengan format: node_YYYY-MM
      final docId = '${node}_${DateFormat('yyyy-MM').format(startDate)}';
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('billing_records')
          .doc(docId)
          .set({
            'docId': docId,
            'nodeName': node,
            'startDate': Timestamp.fromDate(startDate),
            'endDate': Timestamp.fromDate(endDate),
            'meterAwal': meterAwal,
            'meterAkhir': meterAkhir,
            'hargaPerCBM': hargaPerCBM,
            'usage': usage,
            'totalCost': totalCost,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      developer.log('Billing data saved to Firestore for month: ${DateFormat('yyyy-MM').format(startDate)}', 
          name: 'BillingScreen');
    } catch (e) {
      developer.log("Error saving billing data: $e", name: "BillingScreen", error: e);
      rethrow;
    }
  }

  Future<void> _calculateCurrentMonthBill(String node) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final now = DateTime.now();
      startDate = DateTime(now.year, now.month, 1);
      endDate = now;

      // Ambil data debit air saat ini
      final String currentDebitPath = 'last_data/$node/debit_air';
      final DataSnapshot lastDebitSnapshot = await _databaseRef.child(currentDebitPath).get();
      if (!mounted) return;
      double currentDebit = _convertToDouble(lastDebitSnapshot.value);

      // Ambil data bulan lalu untuk meter awal
      final previousMonth = DateTime(now.year, now.month - 1, 1);
      final previousMonthKey = DateFormat('yyyy-MM').format(previousMonth);
      final String previousMonthPath = '$_lastDataPath/$node/$previousMonthKey'; 
      final DataSnapshot previousMonthSnapshot = await _databaseRef.child(previousMonthPath).get();
      if (!mounted) return;

      double previousMonthDebit = 0.0;
      if (previousMonthSnapshot.exists && previousMonthSnapshot.value != null) {
          previousMonthDebit = _convertToDouble(previousMonthSnapshot.value);
      }

      setState(() {
          meterAwal = previousMonthDebit;
          meterAkhir = currentDebit;
          _currentUsage = meterAkhir - meterAwal;
          if (_currentUsage < 0) {
            _currentUsage = 0.0;
          }
          _currentTotalCost = _currentUsage * hargaPerCBM;
      });
    } catch (e) {
        if (mounted) _showErrorSnackBar(messenger, "Error menghitung meteran: $e");
        developer.log("Error calculating current month bill: $e", name: "BillingScreen", error: e);
    }
  }

  Future<void> _loadBillingHistory() async {
    if (!mounted) return;
    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _billingHistory = []);
      return;
    }
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('billing_records')
          .orderBy('startDate', descending: true)
          .get();

      if (mounted) {
        // Filter hanya 12 bulan terakhir
        final twelveMonthsAgo = DateTime.now().subtract(const Duration(days: 365));
        setState(() {
          _billingHistory = querySnapshot.docs
              .where((doc) => (doc.data()['startDate'] as Timestamp).toDate().isAfter(twelveMonthsAgo))
              .map((doc) {
                final data = doc.data();
                return {
                  ...data,
                  'docId': doc.id,
                };
              }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        developer.log("Error loading billing history: $e", name: "BillingScreen");
        setState(() => _billingHistory = []);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = screenHeight * 0.03;

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final activeNode = authProvider.getCurrentNode();

        if ((activeNode != null && activeNode != _activeNode) || (_activeNode == null && activeNode != null)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadInitialData();
          });
        }

        return Scaffold(
          body: Container(
            color: const Color(0xFF62C3D0),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
                    child: Row(
                      children: [
                        const Text("Tagihan Air", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                        const Spacer(),
                        IconButton(
                          icon: Image.asset('images/riwayat2.png', width: 28, height: 28, color: Colors.white,
                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.history, color: Colors.white, size: 28)),
                          onPressed: () async {
                            await _loadBillingHistory();
                            if (!mounted) return;
                            _showMonthlyBillingHistoryDialog();
                          },
                          tooltip: 'Lihat Riwayat Tagihan',
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white, size: 28),
                          onPressed: _loadInitialData,
                          tooltip: 'Refresh Data',
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, color: Colors.white, size: 28),
                          onPressed: _logout,
                          tooltip: 'Logout',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadInitialData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            if (activeNode == null && !_isLoading)
                              Card(
                                color: Colors.white,
                                margin: const EdgeInsets.only(bottom: 20),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    "Node belum dipilih. Silakan pilih node pada halaman Pengawasan terlebih dahulu.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 16, color: Colors.red[700]),
                                  ),
                                ),
                              ),
                            
                            if (_isPreviousMonthBillMissing) _buildMissedBillCard(),
                            
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: const Color(0xF2FFFFFF),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: const [
                                  BoxShadow(color: Color(0x33000000), blurRadius: 15, spreadRadius: 3, offset: Offset(0, 8)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Center(
                                    child: Text("TAGIHAN", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF17778F))),
                                  ),
                                  const Divider(height: 30, thickness: 1.5, color: Color(0xFF17778F)),
                                  _buildDetailRow("Nama", userName, isLoading: _isLoading),
                                  _buildDetailRow("Node", _isLoading ? "Memuat..." : (activeNode ?? "Belum dipilih"), isLoading: false),
                                  const SizedBox(height: 10),
                                  _buildDetailRow("Periode", startDate == null ? "Memuat..." : DateFormat('MMMM yyyy', 'id_ID').format(startDate!), isLoading: _isLoading),
                                  const SizedBox(height: 10),
                                  _buildDetailRow("Meter Awal", "${meterAwal.toStringAsFixed(3)} m\u00B3", isLoading: _isLoading),
                                  _buildDetailRow("Meter Akhir", "${meterAkhir.toStringAsFixed(3)} m\u00B3", isLoading: _isLoading),
                                  _buildDetailRow("Pemakaian", "${_currentUsage.toStringAsFixed(3)} m\u00B3", isLoading: _isLoading),
                                  _buildDetailRow("Harga per m\u00B3", "Rp ${_formatCurrency(hargaPerCBM)}"),
                                  const SizedBox(height: 10),
                                  const Divider(height: 30, thickness: 1.5, color: Color(0xFF17778F)),
                                  
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        const Text("Total Biaya: Rp ", style: TextStyle(color: Color(0xFF17778F), fontSize: 20, fontWeight: FontWeight.bold)),
                                        if (_isLoading)
                                          const Text("Memuat...", style: TextStyle(color: Color(0xFF17778F), fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))
                                        else
                                          Text(_formatCurrency(_currentTotalCost), style: const TextStyle(color: Color(0xFF17778F), fontSize: 20, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  PrimaryStyledButton(
                                    onPressed: _isSavingCurrentBill ? null : _saveCurrentMonthBill,
                                    text: "Simpan Tagihan Bulan Ini",
                                    isLoading: _isSavingCurrentBill,
                                    backgroundColor: const Color(0xFF17778F),
                                    foregroundColor: Colors.white,
                                    leadingIcon: const Icon(Icons.save, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMissedBillCard() {
    final previousMonthString = DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now().subtract(const Duration(days: 30)));
    return Card(
      elevation: 4, margin: const EdgeInsets.only(bottom: 20), color: const Color(0xFFFFF3CD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFFFC107), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFA000), size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Tagihan untuk bulan lalu ($previousMonthString) belum tersimpan.",
                    style: const TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.bold, fontSize: 15,),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryStyledButton(
              onPressed: _isSavingPreviousMonthBill ? null : _manualSavePreviousMonthBill,
              text: "Simpan Tagihan Bulan Lalu", isLoading: _isSavingPreviousMonthBill,
              backgroundColor: const Color(0xFFFFA000), foregroundColor: Colors.white,
              leadingIcon: const Icon(Icons.save_as, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthlyBillingHistoryDialog() {
    if (!mounted) return;

    if (_billingHistory.isEmpty) {
      _showSnackBar(ScaffoldMessenger.of(context), "Belum ada riwayat tagihan.", Colors.grey);
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xF2FFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Riwayat Tagihan", style: TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _billingHistory.length,
              itemBuilder: (context, index) {
                final record = _billingHistory[index];
                final recordDate = (record['startDate'] as Timestamp).toDate();
                final monthName = DateFormat('MMMM yyyy', 'id_ID').format(recordDate);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6), elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: const Color(0xFFE0F2F7),
                  child: ListTile(
                    title: Text(monthName, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF17778F))),
                    subtitle: Text("Pemakaian: ${(record['usage'] as num).toStringAsFixed(3)} m³", style: const TextStyle(color: Color(0xFF004D40))),
                    trailing: Text("Rp ${_formatCurrency((record['totalCost'] as num).toDouble())}"),
                    onTap: () {
                      Navigator.of(dialogContext).pop();
                      _showBillingDetailDialog(record);
                    },
                  ),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text("Tutup", style: TextStyle(color: Color(0xFF17778F))),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  void _showBillingDetailDialog(Map<String, dynamic> billingRecord) {
    if (!mounted) return;

    final recordStartDate = (billingRecord['startDate'] as Timestamp).toDate();
    showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xF2FFFFFF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text("Detail Tagihan\n${DateFormat('MMMM yyyy', 'id_ID').format(recordStartDate)}",
                style: const TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow("Meter Awal", "${(billingRecord['meterAwal'] as num).toStringAsFixed(3)} m\u00B3"),
                  _buildDetailRow("Meter Akhir", "${(billingRecord['meterAkhir'] as num).toStringAsFixed(3)} m\u00B3"),
                  _buildDetailRow("Pemakaian", "${(billingRecord['usage'] as num).toStringAsFixed(3)} m\u00B3"),
                  _buildDetailRow("Harga per m\u00B3", "Rp ${_formatCurrency((billingRecord['hargaPerCBM'] as num).toDouble())}"),
                  const Divider(height: 15, thickness: 1, color: Colors.grey),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text("Total: Rp ${_formatCurrency((billingRecord['totalCost'] as num).toDouble())}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF17778F))),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text("Tutup", style: TextStyle(color: Color(0xFF17778F))),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _confirmAndDeleteBillingRecord(billingRecord);
                },
              ),
            ],
          );
        });
  }

  void _confirmAndDeleteBillingRecord(Map<String, dynamic> billingRecord) {
    if (!mounted) return;

    showDialog(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            backgroundColor: const Color(0xF2FFFFFF),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Konfirmasi Hapus", style: TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold)),
            content: const Text("Yakin ingin menghapus tagihan ini? Tindakan ini tidak dapat diurungkan.", style: TextStyle(color: Color(0xFF17778F))),
            actions: <Widget>[
              TextButton(
                child: const Text("Batal", style: TextStyle(color: Color(0xFF17778F))),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              TextButton(
                child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _deleteBillingRecord(billingRecord);
                },
              ),
            ],
          );
        });
  }

  Future<void> _deleteBillingRecord(Map<String, dynamic> billingRecord) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorSnackBar(messenger, "Anda perlu masuk untuk menghapus data.");
      return;
    }
    final String? docIdToDelete = billingRecord['docId'] as String?;
    if (docIdToDelete == null || docIdToDelete.isEmpty) {
      _showErrorSnackBar(messenger, "Gagal menghapus: ID dokumen tidak ditemukan.");
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('billing_records')
          .doc(docIdToDelete)
          .delete();
      
      // Hapus juga dari Realtime Database jika diperlukan
      final recordDate = (billingRecord['endDate'] as Timestamp).toDate();
      final rtdbKey = DateFormat('yyyy-MM').format(recordDate);
      if (_activeNode != null) {
        await _databaseRef.child(_lastDataPath).child(_activeNode!).child(rtdbKey).remove();
      }
      
      if (!mounted) return;
      
      _showSuccessSnackBar(messenger, "Tagihan berhasil dihapus!");
      await _loadInitialData();
    } catch (e) {
      if (mounted) _showErrorSnackBar(messenger, "Gagal menghapus tagihan: $e");
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0', 'id_ID');
    return formatter.format(amount);
  }

  double _convertToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final sanitizedValue = value.replaceAll(',', '.').trim();
      return double.tryParse(sanitizedValue) ?? 0.0;
    }
    return 0.0;
  }
  
  Future<void> _logout() async {
    if (!mounted) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    
    await authProvider.signOut();
    
    if (!mounted) return;
    
    navigator.pushNamedAndRemoveUntil('/checkauth', (route) => false);
  }

  void _showSnackBar(ScaffoldMessengerState messenger, String message, Color backgroundColor) {
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(ScaffoldMessengerState messenger, String message) {
    _showSnackBar(messenger, message, Colors.red);
  }

  void _showSuccessSnackBar(ScaffoldMessengerState messenger, String message) {
    _showSnackBar(messenger, message, const Color(0xFF17778F));
  }

  Widget _buildDetailRow(String label, String value, {bool isLoading = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Color(0xFF17778F), fontWeight: FontWeight.w600)),
          if (isLoading)
            const Text("Memuat...", style: TextStyle(fontSize: 16, color: Color(0xFF17778F), fontStyle: FontStyle.italic))
          else
            Text(value, style: const TextStyle(fontSize: 16, color: Color(0xFF17778F))),
        ],
      ),
    );
  }
}