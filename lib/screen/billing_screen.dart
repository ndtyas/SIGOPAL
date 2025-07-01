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
  static const String _historyPath = 'debit_history'; // Menggunakan _historyPath

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
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _initializeFirebase() {
    try {
      _databaseRef = FirebaseDatabase.instance.ref();
      developer.log('Firebase initialized successfully in BillingScreen', name: 'BillingScreen');
    } catch (e) {
      developer.log('Error initializing Firebase in BillingScreen: $e', name: 'BillingScreen');
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

  void _loadUserDataAndBilling() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      meterAwal = 0.0; // Reset values to show loading state
      meterAkhir = 0.0;
      _currentUsage = 0.0;
      _currentTotalCost = 0.0;
      startDate = null;
      endDate = null;
    });

    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
            _showErrorSnackBar("Tidak dapat menemukan node. Harap masukkan node di halaman sebelumnya.");
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
      // 1. Ambil data meter akhir (data terakhir) dari debit_air
      final DataSnapshot lastDebitSnapshot = await _databaseRef
          .child(_lastDataPath)
          .child(node)
          .child('debit_air')
          .get();

      double lastDebit = 0.0;
      if (lastDebitSnapshot.exists && lastDebitSnapshot.value != null) {
        lastDebit = (lastDebitSnapshot.value as num?)?.toDouble() ?? 0.0;
      }
      developer.log('Meter Akhir (last_data/debit_air): $lastDebit', name: 'BillingScreen');

      // 2. Ambil data meter awal (debit air bulan kemarin)
      double startDebit = 0.0;
      
      final now = DateTime.now();
      endDate = DateTime(now.year, now.month, now.day, now.hour, now.minute, now.second); 
      
      // Calculate the start date for the previous month's reading
      // If current month is July 2025, we want the last reading from June 2025.
      // So, startOfCurrentMonth is July 1, 2025.
      // We look for a reading just before July 1, 2025 (i.e., end of June 2025).
      final startOfCurrentMonth = DateTime(now.year, now.month, 1);
      
      // Set startDate to the first day of the previous month for display purposes
      startDate = DateTime(now.year, now.month - 1, 1);


      final historyRef = _databaseRef.child(_historyPath).child(node); // Menggunakan _historyPath
      final DataSnapshot historySnapshot = await historyRef
          .orderByKey()
          .endAt((startOfCurrentMonth.millisecondsSinceEpoch - 1).toString()) // Cari sebelum awal bulan ini
          .limitToLast(1) 
          .get();

      if (historySnapshot.exists && historySnapshot.value != null) {
        final Map<dynamic, dynamic>? historyData = historySnapshot.value as Map<dynamic, dynamic>?;
        if (historyData != null && historyData.isNotEmpty) {
          final String lastTimestampKey = historyData.keys.first;
          final double? value = (historyData[lastTimestampKey] as num?)?.toDouble();
          if (value != null) {
            startDebit = value;
            developer.log('Meter Awal (from history before current month): $startDebit', name: 'BillingScreen');
          } else {
              developer.log('History data exists but value is null for key: $lastTimestampKey', name: 'BillingScreen');
          }
        }
      } else {
        developer.log('No historical debit data found for node $node before ${DateFormat('dd-MM-yyyy').format(startOfCurrentMonth)}', name: 'BillingScreen');
        // Peringatan ini bisa diubah menjadi _showInfoSnackBar jika Anda ingin memberitahu pengguna
        _showInfoSnackBar("Tidak ada riwayat meter awal bulan lalu. Meter awal diatur ke 0.");
      }
      
      setState(() {
        meterAwal = startDebit;
        meterAkhir = lastDebit;
        _currentUsage = meterAkhir - meterAwal;
        if (_currentUsage < 0) _currentUsage = 0.0;
        _currentTotalCost = _currentUsage * hargaPerCBM;

        // this.startDate = startDate; // Peringatan: Unnecessary 'this.' qualifier
        // this.endDate = endDate;   // Peringatan: Unnecessary 'this.' qualifier
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


  void _saveBillingData() async {
    final user = auth_firebase.FirebaseAuth.instance.currentUser;
    if (user == null || startDate == null || endDate == null || _activeNode == null) {
      if (mounted) {
        _showErrorSnackBar("Data tidak lengkap untuk disimpan. Pastikan node dan tanggal telah dipilih.");
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
        'nodeName': _activeNode,
      });

      if (mounted) {
        _showSuccessSnackBar("Data tagihan berhasil disimpan!");
        _loadBillingHistory();
        // Reset state untuk tampilan tagihan saat ini setelah disimpan
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
    final user = auth_firebase.FirebaseAuth.instance.currentUser;
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
                    // New placement for the history icon button
                    IconButton(
                      icon: Image.asset(
                        'images/riwayat2.png', // Path gambar yang baru
                        width: 28, // Ukuran ikon sesuai dengan ikon lain
                        height: 28,
                        color: Colors.white, // Sesuaikan warna jika gambar berupa ikon satu warna
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.history, // Fallback icon jika gambar tidak ditemukan
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
                        _loadUserDataAndBilling(); // Refresh data tagihan saat ini
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
                            // The "LIHAT RIWAYAT TAGIHAN" button and its SizedBox are removed from here
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