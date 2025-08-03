import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sigopal/provider/auth_provider.dart' as custom_auth;
import 'package:intl/intl.dart';

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({super.key});

  @override
  State<AdminBillingScreen> createState() => _AdminBillingScreenState();
}

class _AdminBillingScreenState extends State<AdminBillingScreen> {
  String _selectedFilter = 'all';
  final Map<String, String> _userCache = {}; // Cache untuk username

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<custom_auth.AuthProvider>(context);

    // Security check
    if (!auth.isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFF62C3D0),
        body: const SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 64, color: Colors.white),
                SizedBox(height: 16),
                Text(
                  'Anda tidak memiliki akses admin',
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF62C3D0),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar yang fleksibel
            _buildFlexibleAppBar(auth),
            
            // Summary Card - Jumlah tagihan dan harga air
            _buildSummaryCard(),
            
            // Billing List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getBillingRecordsStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorWidget(snapshot.error.toString());
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingWidget();
                  }

                  final billingRecords = snapshot.data?.docs ?? [];
                  final filteredRecords = _filterRecords(billingRecords)
                      .where((record) {
                        final data = record.data() as Map<String, dynamic>;
                        final amount = data['amount'] ?? 0;
                        return amount != 0; // Filter out records with amount 0
                      }).toList();

                  if (filteredRecords.isEmpty) {
                    return _buildEmptyWidget();
                  }

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Responsive grid/list berdasarkan lebar layar
                      if (constraints.maxWidth > 900) {
                        // Grid untuk layar sangat lebar
                        return GridView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.05,
                          ),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 1.6, // Adjusted for better fit
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredRecords.length,
                          itemBuilder: (context, index) {
                            final record = filteredRecords[index];
                            final data = record.data() as Map<String, dynamic>;
                            final userId = record.reference.parent.parent!.id;
                            return _buildBillingCard(data, record.id, userId);
                          },
                        );
                      } else {
                        // List untuk layar normal dan sempit
                        return ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.05,
                          ),
                          itemCount: filteredRecords.length,
                          itemBuilder: (context, index) {
                            final record = filteredRecords[index];
                            final data = record.data() as Map<String, dynamic>;
                            final userId = record.reference.parent.parent!.id;
                            return _buildBillingCard(data, record.id, userId);
                          },
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlexibleAppBar(custom_auth.AuthProvider auth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF62C3D0),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              // Title section
              const Expanded(
                child: Text(
                  "Riwayat Tagihan",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              
              // Action buttons - responsive layout
              if (constraints.maxWidth > 400) ...[
                // Desktop/Tablet layout - horizontal buttons
                _buildEditPriceButton(), // Tombol baru untuk ubah harga
                const SizedBox(width: 8),
                _buildFilterButton(),
                const SizedBox(width: 8),
                _buildRefreshButton(),
                const SizedBox(width: 8),
                _buildLogoutButton(auth),
              ] else ...[
                // Mobile layout - compact menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit_price': // Opsi baru untuk ubah harga
                        _showEditPriceDialog();
                        break;
                      case 'filter':
                        _showFilterDialog();
                        break;
                      case 'refresh':
                        setState(() {
                          _userCache.clear();
                        });
                        break;
                      case 'logout':
                        _showLogoutDialog(context, auth);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem( // Opsi baru di menu
                      value: 'edit_price',
                      child: Row(
                        children: [
                          Icon(Icons.monetization_on, color: Color(0xFF62C3D0)),
                          SizedBox(width: 8),
                          Text('Ubah Harga Air'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'filter',
                      child: Row(
                        children: [
                          Icon(Icons.filter_list, color: Color(0xFF62C3D0)),
                          SizedBox(width: 8),
                          Text('Filter'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, color: Color(0xFF62C3D0)),
                          SizedBox(width: 8),
                          Text('Refresh'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Logout'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0x1A000000),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _getBillingRecordsStream(),
        builder: (context, billingSnapshot) {
          if (billingSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF62C3D0)),
            );
          }
  
          final records = billingSnapshot.data?.docs ?? [];
          final nonZeroRecords = records.where((record) {
            final data = record.data() as Map<String, dynamic>;
            return (data['amount'] ?? 0) != 0;
          }).toList();
          
          double totalAmount = 0;
          int paidCount = 0;
          int unpaidCount = 0;
          int overdueCount = 0;
  
          for (var record in nonZeroRecords) {
            final data = record.data() as Map<String, dynamic>;
            final amount = data['amount'] ?? 0;
            final status = data['status'] ?? 'unpaid';
            
            totalAmount += (amount is num ? amount : 0);
            
            switch (status) {
              case 'paid': paidCount++; break;
              case 'overdue': overdueCount++; break;
              default: unpaidCount++;
            }
          }
  
          // --- NEW: StreamBuilder to get water price ---
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').doc('main').snapshots(),
            builder: (context, priceSnapshot) {
              double hargaPerCBM = 0.0;
              if (priceSnapshot.hasData && priceSnapshot.data!.exists) {
                final priceData = priceSnapshot.data!.data() as Map<String, dynamic>;
                hargaPerCBM = (priceData['hargaPerCBM'] as num?)?.toDouble() ?? 0.0;
              }
  
              return Column(
                children: [
                  const Row(
                    children: [
                      Icon(Icons.dashboard, color: Color(0xFF62C3D0), size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Ringkasan',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF17778F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 800) { // Increased breakpoint for 5 items
                        return Row(
                          children: [
                            Expanded(child: _buildSummaryItem('Harga / M³', _formatCurrency(hargaPerCBM), Icons.monetization_on, Colors.purple)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSummaryItem('Total Tagihan', _formatCurrency(totalAmount), Icons.account_balance_wallet, Colors.blue)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSummaryItem('Sudah Bayar', '$paidCount', Icons.check_circle, Colors.green)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSummaryItem('Belum Bayar', '$unpaidCount', Icons.pending, Colors.orange)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSummaryItem('Terlambat', '$overdueCount', Icons.warning, Colors.red)),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildSummaryItem('Harga / M³', _formatCurrency(hargaPerCBM), Icons.monetization_on, Colors.purple),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildSummaryItem('Total Tagihan', _formatCurrency(totalAmount), Icons.account_balance_wallet, Colors.blue)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSummaryItem('Sudah Bayar', '$paidCount', Icons.check_circle, Colors.green)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: _buildSummaryItem('Belum Bayar', '$unpaidCount', Icons.pending, Colors.orange)),
                                const SizedBox(width: 16),
                                Expanded(child: _buildSummaryItem('Terlambat', '$overdueCount', Icons.warning, Colors.red)),
                              ],
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Semua Status'),
              value: 'all',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Sudah Dibayar'),
              value: 'paid',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Belum Dibayar'),
              value: 'unpaid',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('Terlambat'),
              value: 'overdue',
              groupValue: _selectedFilter,
              onChanged: (value) {
                setState(() {
                  _selectedFilter = value!;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.filter_list, color: Colors.white, size: 24),
      tooltip: 'Filter Status',
      onSelected: (value) {
        setState(() {
          _selectedFilter = value;
        });
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'all',
          child: Text('Semua Status'),
        ),
        const PopupMenuItem(
          value: 'paid',
          child: Text('Sudah Dibayar'),
        ),
        const PopupMenuItem(
          value: 'unpaid',
          child: Text('Belum Dibayar'),
        ),
        const PopupMenuItem(
          value: 'overdue',
          child: Text('Terlambat'),
        ),
      ],
    );
  }

  // --- WIDGET BARU ---
  Widget _buildEditPriceButton() {
    return IconButton(
      icon: const Icon(Icons.monetization_on, color: Colors.white, size: 24),
      onPressed: _showEditPriceDialog,
      tooltip: 'Ubah Harga Air',
    );
  }

  Widget _buildRefreshButton() {
    return IconButton(
      icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
      onPressed: () => setState(() {
        _userCache.clear(); // Clear cache saat refresh
      }),
      tooltip: 'Refresh',
    );
  }

  Widget _buildLogoutButton(custom_auth.AuthProvider auth) {
    return IconButton(
      icon: const Icon(Icons.logout, color: Colors.white, size: 24),
      onPressed: () => _showLogoutDialog(context, auth),
      tooltip: 'Logout',
    );
  }

  Future<String> _getUserName(String userId) async {
    if (_userCache.containsKey(userId)) {
      return _userCache[userId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        final username = userData['username'] ?? 
                         userData['name'] ?? 
                         userData['email'] ?? 
                         'User $userId';
        
        _userCache[userId] = username;
        return username;
      } else {
        _userCache[userId] = 'User $userId';
        return 'User $userId';
      }
    } catch (e) {
      debugPrint('Error getting username: $e');
      _userCache[userId] = 'User $userId';
      return 'User $userId';
    }
  }

  Stream<QuerySnapshot> _getBillingRecordsStream() {
    return FirebaseFirestore.instance
        .collectionGroup('billing_records')
        .snapshots();
  }

  List<QueryDocumentSnapshot> _filterRecords(List<QueryDocumentSnapshot> records) {
    records.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aCreated = aData['created_at'] as Timestamp?;
      final bCreated = bData['created_at'] as Timestamp?;
      
      if (aCreated == null && bCreated == null) return 0;
      if (aCreated == null) return 1;
      if (bCreated == null) return -1;
      
      return bCreated.compareTo(aCreated);
    });
    
    if (_selectedFilter == 'all') return records;
    
    return records.where((record) {
      final data = record.data() as Map<String, dynamic>;
      final status = data['status'] ?? 'unpaid';
      return status == _selectedFilter;
    }).toList();
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Terjadi kesalahan saat memuat data.\n\nError: $error',
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() {}),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF62C3D0),
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Memuat data tagihan...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.white),
          const SizedBox(height: 16),
          Text(
            _getEmptyMessage(),
            style: const TextStyle(fontSize: 18, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_selectedFilter) {
      case 'paid':
        return 'Belum ada tagihan yang dibayar';
      case 'unpaid':
        return 'Tidak ada tagihan yang belum dibayar';
      case 'overdue':
        return 'Tidak ada tagihan yang terlambat';
      default:
        return 'Belum ada data tagihan';
    }
  }

  Widget _buildBillingCard(Map<String, dynamic> data, String recordId, String userId) {
    final status = data['status'] ?? 'unpaid';
    final amount = data['amount'] ?? 0;
    final description = data['description'] ?? 'Tagihan';
    final dueDate = data['due_date'];
    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0F000000),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF62C3D0),
                radius: 20,
                child: Icon(statusInfo['icon'], color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF17778F)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<String>(
                      future: _getUserName(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Memuat...', style: TextStyle(color: Colors.grey, fontSize: 12));
                        }
                        return Text(
                          snapshot.data ?? 'Unknown User',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        );
                      },
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Color(0xFF62C3D0), size: 20),
                onSelected: (value) {
                  if (value == 'details') {
                    _showBillDetails(context, data, recordId, userId);
                  } else if (value == 'edit_status') {
                    _showEditStatusDialog(context, data, recordId, userId);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: Row(children: [Icon(Icons.info_outline, color: Color(0xFF62C3D0), size: 18), SizedBox(width: 8), Text('Detail')]),
                  ),
                  const PopupMenuItem(
                    value: 'edit_status',
                    child: Row(children: [Icon(Icons.edit, color: Color(0xFF62C3D0), size: 18), SizedBox(width: 8), Text('Ubah Status')]),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 300) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: _buildAmountSection(amount)),
                    if (dueDate != null) _buildDueDateSection(dueDate),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAmountSection(amount),
                    if (dueDate != null) ...[const SizedBox(height: 8), _buildDueDateSection(dueDate)],
                  ],
                );
              }
            },
          ),
          
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusInfo['color'],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(statusInfo['icon'], size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(statusInfo['text'], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection(dynamic amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Jumlah Tagihan', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          _formatCurrency(amount),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF17778F)),
        ),
      ],
    );
  }

  Widget _buildDueDateSection(dynamic dueDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('Jatuh Tempo', style: TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          _formatDate(dueDate),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF17778F)),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'paid':
        return {'color': Colors.green, 'icon': Icons.check_circle, 'text': 'DIBAYAR'};
      case 'overdue':
        return {'color': Colors.red, 'icon': Icons.warning, 'text': 'TERLAMBAT'};
      default: // 'unpaid'
        return {'color': Colors.orange, 'icon': Icons.pending, 'text': 'BELUM BAYAR'};
    }
  }

  String _formatCurrency(dynamic amount) {
    final format = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    if (amount is! num) return format.format(0);
    return format.format(amount);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final DateFormat formatter = DateFormat('d MMM yyyy', 'id_ID');
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'N/A';
      }
      return formatter.format(date);
    } catch (e) {
      return 'N/A';
    }
  }

  void _showBillDetails(BuildContext context, Map<String, dynamic> data, String recordId, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.receipt_long, color: Color(0xFF62C3D0)), SizedBox(width: 8), Text('Detail Tagihan')]),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.8,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: FutureBuilder<String>(
                    future: _getUserName(userId),
                    builder: (context, snapshot) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person, color: Color(0xFF62C3D0), size: 20),
                              const SizedBox(width: 8),
                              Text(snapshot.data ?? 'Memuat...', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF17778F))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('ID: $userId', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      );
                    },
                  ),
                ),
                _buildSimpleDetailRow('Deskripsi', data['description'] ?? 'N/A'),
                _buildSimpleDetailRow('Jumlah', _formatCurrency(data['amount'])),
                _buildSimpleDetailRow('Status', _getStatusText(data['status'] ?? 'unpaid')),
                if (data['due_date'] != null) _buildSimpleDetailRow('Jatuh Tempo', _formatDate(data['due_date'])),
                if (data['created_at'] != null) _buildSimpleDetailRow('Dibuat Pada', _formatDate(data['created_at'])),
                const SizedBox(height: 8),
                Text('ID Record: $recordId', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontFamily: 'monospace')),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))],
      ),
    );
  }

  Widget _buildSimpleDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF17778F)))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid': return 'Sudah Dibayar';
      case 'overdue': return 'Terlambat';
      default: return 'Belum Dibayar';
    }
  }

  void _showEditStatusDialog(BuildContext context, Map<String, dynamic> data, String recordId, String userId) {
    String selectedStatus = data['status'] ?? 'unpaid';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [Icon(Icons.edit, color: Color(0xFF62C3D0)), SizedBox(width: 8), Text('Ubah Status Tagihan')]),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                      child: FutureBuilder<String>(
                        future: _getUserName(userId),
                        builder: (context, snapshot) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('User: ${snapshot.data ?? 'Memuat...'}'),
                              Text('Tagihan: ${data['description'] ?? 'N/A'}'),
                              Text('Jumlah: ${_formatCurrency(data['amount'])}'),
                            ],
                          );
                        },
                      ),
                    ),
                    RadioListTile<String>(
                      title: const Text('Belum Dibayar'), value: 'unpaid', groupValue: selectedStatus,
                      onChanged: (value) => value != null ? setDialogState(() => selectedStatus = value) : null,
                    ),
                    RadioListTile<String>(
                      title: const Text('Sudah Dibayar'), value: 'paid', groupValue: selectedStatus,
                      onChanged: (value) => value != null ? setDialogState(() => selectedStatus = value) : null,
                    ),
                    RadioListTile<String>(
                      title: const Text('Terlambat'), value: 'overdue', groupValue: selectedStatus,
                      onChanged: (value) => value != null ? setDialogState(() => selectedStatus = value) : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateBillStatus(userId, recordId, selectedStatus);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF62C3D0), foregroundColor: Colors.white),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FUNGSI BARU: Menampilkan dialog untuk edit harga ---
  void _showEditPriceDialog() {
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('settings').doc('main').snapshots(),
          builder: (context, snapshot) {
            String currentPriceStr = "0";
            bool isLoading = !snapshot.hasData;

            if (!isLoading && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final currentPrice = (data['hargaPerCBM'] as num?)?.toDouble() ?? 0.0;
              currentPriceStr = currentPrice.toString();
              if (priceController.text.isEmpty) {
                priceController.text = currentPriceStr;
              }
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.monetization_on, color: Color(0xFF62C3D0)),
                  SizedBox(width: 8),
                  Text('Ubah Harga per M³'),
                ],
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Harga saat ini: ${_formatCurrency(double.tryParse(currentPriceStr) ?? 0)}"),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: priceController,
                      enabled: !isLoading,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Harga Baru per M³',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                        helperText: 'Gunakan titik untuk desimal',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Harga tidak boleh kosong';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Masukkan angka yang valid';
                        }
                        if (double.parse(value) < 0) {
                          return 'Harga tidak boleh negatif';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: isLoading ? null : () {
                    if (formKey.currentState!.validate()) {
                      final newPrice = double.parse(priceController.text);
                      _updateWaterPrice(newPrice);
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF62C3D0),
                    foregroundColor: Colors.white,
                  ),
                  child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- FUNGSI BARU: Mengupdate harga di Firestore ---
  void _updateWaterPrice(double newPrice) async {
    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('main')
          .set({'hargaPerCBM': newPrice}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harga air berhasil diupdate'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengupdate harga: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateBillStatus(String userId, String recordId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('billing_records')
          .doc(recordId)
          .update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status tagihan berhasil diupdate'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context, custom_auth.AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.logout, color: Colors.red), SizedBox(width: 8), Text('Konfirmasi Logout')]),
        content: const Text('Apakah Anda yakin ingin keluar dari akun admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              navigator.pop(); // Close confirmation dialog

              showDialog( // Show loading dialog
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.white)),
              );

              try {
                await auth.signOut();
                if (!mounted) return;
                navigator.pop(); // Close loading dialog
                navigator.pushReplacementNamed('/welcome');
              } catch (e) {
                if (!mounted) return;
                navigator.pop(); // Close loading dialog
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Error saat logout: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}