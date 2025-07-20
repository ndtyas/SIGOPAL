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

// Kelas utama untuk layar tagihan
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

  /// State untuk melacak apakah tagihan kemarin terlewat dan proses penyimpanannya.
  bool _isYesterdayBillMissing = false;
  bool _isSavingYesterdayBill = false;

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

  Future<void> _debugDatabaseStructure() async {
    if (_activeNode == null) {
      developer.log('Debug skipped: No active node.', name: 'BillingScreen.Debug');
      return;
    }
    developer.log('--- Starting Database Structure Debug for node: $_activeNode ---', name: 'BillingScreen.Debug');
    try {
      final path = 'last_data/$_activeNode';
      developer.log('Checking path: /$path', name: 'BillingScreen.Debug');
      final snapshot = await _databaseRef.child(path).get();
      if (snapshot.exists) {
        developer.log('SUCCESS: Data found at path "/$path".', name: 'BillingScreen.Debug');
        developer.log('Snapshot value: ${snapshot.value}', name: 'BillingScreen.Debug');
        if (snapshot.value is Map) {
          final dataMap = snapshot.value as Map;
          if (dataMap.containsKey('debit_air')) {
            developer.log('>>> Key "debit_air" FOUND! Value: ${dataMap['debit_air']}', name: 'BillingScreen.Debug');
          } else {
            developer.log('--- Key "debit_air" NOT found at this path.', name: 'BillingScreen.Debug');
          }
        }
      } else {
        developer.log('INFO: No data found at path "/$path".', name: 'BillingScreen.Debug');
      }
    } catch (e) {
      developer.log('Error during database debug: $e', name: 'BillingScreen.Debug');
    }
    developer.log('--- Finished Database Structure Debug ---', name: 'BillingScreen.Debug');
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
          _isYesterdayBillMissing = false;
        });

        if (retrievedNode != null) {
          await _debugDatabaseStructure();
          
          await _checkIfPreviousDayBillIsMissing(user.uid, retrievedNode);
          await _calculateCurrentDayBill(retrievedNode);
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

  Future<void> _checkIfPreviousDayBillIsMissing(String userId, String node) async {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final startOfYesterday = Timestamp.fromDate(yesterday);
    final startOfToday = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('billing_records')
          .where('nodeName', isEqualTo: node)
          .where('startDate', isGreaterThanOrEqualTo: startOfYesterday)
          .where('startDate', isLessThan: startOfToday)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isYesterdayBillMissing = querySnapshot.docs.isEmpty;
        });
      }
    } catch (e) {
      developer.log("Error checking yesterday's bill: $e", name: "BillingScreen");
      if (mounted) setState(() => _isYesterdayBillMissing = false);
    }
  }

  Future<void> _manualSavePreviousDayBill() async {
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

    setState(() => _isSavingYesterdayBill = true);

    final String node = _activeNode!;
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    try {
      final yesterdayKey = DateFormat('yyyy-MM-dd').format(yesterday);
      final yesterdaySnapshot = await _databaseRef.child(_lastDataPath).child(node).child(yesterdayKey).get();

      if (!mounted) return;
      if (!yesterdaySnapshot.exists || yesterdaySnapshot.value == null) {
        _showErrorSnackBar(messenger, "Gagal menyimpan: Data meteran kemarin tidak ditemukan.");
        setState(() => _isSavingYesterdayBill = false);
        return;
      }
      final meterAkhirKemarin = _convertToDouble(yesterdaySnapshot.value);

      final twoDaysAgo = yesterday.subtract(const Duration(days: 1));
      final twoDaysAgoKey = DateFormat('yyyy-MM-dd').format(twoDaysAgo);
      final twoDaysAgoSnapshot = await _databaseRef.child(_lastDataPath).child(node).child(twoDaysAgoKey).get();
      
      if (!mounted) return;
      final meterAwalKemarin = _convertToDouble(twoDaysAgoSnapshot.value);

      final usageKemarin = meterAkhirKemarin - meterAwalKemarin;
      final costKemarin = (usageKemarin > 0 ? usageKemarin : 0) * hargaPerCBM;

      await _saveBillingDataInternal(
        user.uid, node, yesterday, yesterday.add(const Duration(hours: 23, minutes: 59, seconds: 59)),
        meterAwalKemarin, meterAkhirKemarin, hargaPerCBM,
        usageKemarin > 0 ? usageKemarin : 0, costKemarin,
      );

      if (!mounted) return;
      _showSuccessSnackBar(messenger, "Tagihan kemarin berhasil disimpan!");
      await _loadInitialData();
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(messenger, "Gagal menyimpan tagihan kemarin: $e");
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingYesterdayBill = false);
      }
    }
  }

  Future<void> _calculateCurrentDayBill(String node) async {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
        final now = DateTime.now();
        startDate = DateTime(now.year, now.month, now.day);
        endDate = now;

        final String currentDebitPath = 'last_data/$node/debit_air';
        developer.log('Attempting to read current debit from RTDB path: /$currentDebitPath', name: 'BillingScreen');
        final DataSnapshot lastDebitSnapshot = await _databaseRef.child(currentDebitPath).get();
        if (!mounted) return;
        double currentDebit = _convertToDouble(lastDebitSnapshot.value);
        developer.log('Value received for currentDebit: ${lastDebitSnapshot.value} -> Parsed as: $currentDebit', name: 'BillingScreen');

        final yesterday = now.subtract(const Duration(days: 1));
        final yesterdayKey = DateFormat('yyyy-MM-dd').format(yesterday);
        final String previousDayPath = '$_lastDataPath/$node/$yesterdayKey'; 
        developer.log('Attempting to read previous day debit from RTDB path: /$previousDayPath', name: 'BillingScreen');
        final DataSnapshot previousDaySnapshot = await _databaseRef.child(previousDayPath).get();
        if (!mounted) return;

        double previousDayDebit = 0.0;
        if (previousDaySnapshot.exists && previousDaySnapshot.value != null) {
            previousDayDebit = _convertToDouble(previousDaySnapshot.value);
            developer.log('Value received for previousDayDebit: ${previousDaySnapshot.value} -> Parsed as: $previousDayDebit', name: 'BillingScreen');
        } else {
            developer.log('No data found for previous day\'s debit.', name: 'BillingScreen');
        }

        setState(() {
            meterAwal = previousDayDebit;
            meterAkhir = currentDebit;
            _currentUsage = meterAkhir - meterAwal;
            if (_currentUsage < 0) {
              developer.log('Current usage is negative ($_currentUsage). Resetting to 0.', name: 'BillingScreen');
              _currentUsage = 0.0;
            }
            _currentTotalCost = _currentUsage * hargaPerCBM;
        });
    } catch (e) {
        if (mounted) _showErrorSnackBar(messenger, "Error menghitung meteran: $e");
        developer.log("Error calculating current day bill: $e", name: "BillingScreen", error: e);
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
          .collection('users').doc(user.uid).collection('billing_records')
          .orderBy('startDate', descending: true).limit(90).get();

      if (mounted) {
        setState(() {
          _billingHistory = querySnapshot.docs.map((doc) => doc.data()).toList();
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
                            
                            if (_isYesterdayBillMissing) _buildMissedBillCard(),
                            
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
                                    child: Text("TAGIHAN HARI INI", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF17778F))),
                                  ),
                                  const Divider(height: 30, thickness: 1.5, color: Color(0xFF17778F)),
                                  _buildDetailRow("Nama", userName, isLoading: _isLoading),
                                  _buildDetailRow("Node", _isLoading ? "Memuat..." : (activeNode ?? "Belum dipilih"), isLoading: false),
                                  const SizedBox(height: 10),
                                  _buildDetailRow("Tanggal", startDate == null ? "Memuat..." : DateFormat('dd MMMM yyyy').format(startDate!), isLoading: _isLoading),
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
                                        const Text("Total Biaya: Rp ", style: TextStyle(color: Color(0xFF17778F), fontSize: 20, fontWeight: FontWeight.bold)),
                                        if (_isLoading)
                                          const Text("Memuat...", style: TextStyle(color: Color(0xFF17778F), fontSize: 20, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))
                                        else
                                          Text(_formatCurrency(_currentTotalCost), style: const TextStyle(color: Color(0xFF17778F), fontSize: 20, fontWeight: FontWeight.bold)),
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
    final yesterdayString = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now().subtract(const Duration(days: 1)));
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
                    "Tagihan untuk hari kemarin ($yesterdayString) belum tersimpan.",
                    style: const TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.bold, fontSize: 15,),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryStyledButton(
              onPressed: _isSavingYesterdayBill ? null : _manualSavePreviousDayBill,
              text: "Simpan Tagihan Kemarin", isLoading: _isSavingYesterdayBill,
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

    final Map<String, List<Map<String, dynamic>>> monthlyHistory = {};
    for (var record in _billingHistory) {
      final recordStartDate = (record['startDate'] as Timestamp).toDate();
      final monthKey = DateFormat('MMMM yyyy', 'id_ID').format(recordStartDate);
      monthlyHistory.putIfAbsent(monthKey, () => []).add(record);
    }

    final sortedMonths = monthlyHistory.keys.toList()
      ..sort((a, b) => DateFormat('MMMM yyyy', 'id_ID').parse(b).compareTo(DateFormat('MMMM yyyy', 'id_ID').parse(a)));

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xF2FFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Riwayat Tagihan Bulanan", style: TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: sortedMonths.length,
              itemBuilder: (context, index) {
                final month = sortedMonths[index];
                final dailyRecords = monthlyHistory[month]!;
                final double monthlyTotal = dailyRecords.fold(0.0, (total, record) => total + (record['totalCost'] as num));

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6), elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: const Color(0xFFE0F2F7),
                  child: ExpansionTile(
                    title: Text(month, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF17778F))),
                    subtitle: Text("Total: Rp ${_formatCurrency(monthlyTotal)}", style: const TextStyle(color: Color(0xFF004D40))),
                    children: dailyRecords.map((record) {
                      final recordDate = (record['startDate'] as Timestamp).toDate();
                      return ListTile(
                        title: Text(DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(recordDate)),
                        trailing: Text("Rp ${_formatCurrency((record['totalCost'] as num).toDouble())}"),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          _showBillingDetailDialog(record);
                        },
                      );
                    }).toList(),
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

  Future<void> _saveBillingDataInternal(String userId, String node, DateTime startDt, DateTime endDt, double mtrAwal, double mtrAkhir, double hargaCBM, double usage, double totalCost) async {
    try {
      String docId = DateFormat('yyyyMMdd_HHmmss_SSS').format(DateTime.now());
      await FirebaseFirestore.instance.collection('users').doc(userId).collection('billing_records').doc(docId).set({
        'startDate': Timestamp.fromDate(startDt), 'endDate': Timestamp.fromDate(endDt),
        'meterAwal': mtrAwal, 'meterAkhir': mtrAkhir, 'hargaPerCBM': hargaCBM,
        'usage': usage, 'totalCost': totalCost, 'timestamp': FieldValue.serverTimestamp(),
        'docId': docId, 'nodeName': node,
      });
      final dayToSaveKey = DateFormat('yyyy-MM-dd').format(startDt);
      await _databaseRef.child(_lastDataPath).child(node).update({ dayToSaveKey: mtrAkhir.toStringAsFixed(4) }); // Simpan sebagai string
      developer.log('Saved meterAkhir ($mtrAkhir) to RTDB at $_lastDataPath/$node/$dayToSaveKey', name: 'BillingScreen');
    } catch (e) {
      developer.log("Error saving billing data: $e", name: "BillingScreen", error: e);
      rethrow;
    }
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
            title: Text("Detail Tagihan\n${DateFormat('dd MMMM yyyy', 'id_ID').format(recordStartDate)}",
                style: const TextStyle(color: Color(0xFF17778F), fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow("Meter Awal", "${(billingRecord['meterAwal'] as num).toDouble().toStringAsFixed(2)} m\u00B3"),
                  _buildDetailRow("Meter Akhir", "${(billingRecord['meterAkhir'] as num).toDouble().toStringAsFixed(2)} m\u00B3"),
                  _buildDetailRow("Pemakaian", "${(billingRecord['usage'] as num).toDouble().toStringAsFixed(2)} m\u00B3"),
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
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('billing_records').doc(docIdToDelete).delete();
      final recordDate = (billingRecord['endDate'] as Timestamp).toDate();
      final rtdbKey = DateFormat('yyyy-MM-dd').format(recordDate);
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