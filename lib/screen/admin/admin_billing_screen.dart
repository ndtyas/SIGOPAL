import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sigopal/provider/auth_provider.dart' as custom_auth;

class AdminBillingScreen extends StatefulWidget {
  const AdminBillingScreen({super.key});

  @override
  State<AdminBillingScreen> createState() => _AdminBillingScreenState();
}

class _AdminBillingScreenState extends State<AdminBillingScreen> {
  String _selectedFilter = 'all'; // all, paid, unpaid, overdue
  
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<custom_auth.AuthProvider>(context);

    // Security check - pastikan user benar-benar admin
    if (!auth.isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Akses Ditolak'),
          backgroundColor: Colors.red,
        ),
        body: const Center(
          child: Text(
            'Anda tidak memiliki akses admin',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Tagihan'),
        backgroundColor: const Color.fromARGB(255, 11, 58, 70),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('Semua Tagihan'),
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
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 11, 58, 70),
              Color.fromARGB(255, 20, 85, 100),
            ],
          ),
        ),
        child: Column(
          children: [
            // Filter Chips
            Container(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('all', 'Semua'),
                    const SizedBox(width: 8),
                    _buildFilterChip('paid', 'Dibayar'),
                    const SizedBox(width: 8),
                    _buildFilterChip('unpaid', 'Belum Bayar'),
                    const SizedBox(width: 8),
                    _buildFilterChip('overdue', 'Terlambat'),
                  ],
                ),
              ),
            ),
            
            // Billing List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getBillingStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 64, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Error: ${snapshot.error}',
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Coba Lagi'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
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

                  final bills = snapshot.data?.docs ?? [];

                  if (bills.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _getEmptyMessage(),
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white54,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final bill = bills[index];
                      final data = bill.data() as Map<String, dynamic>;
                      
                      return _buildBillingCard(data, bill.id);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateBillDialog(),
        backgroundColor: const Color.fromARGB(255, 98, 195, 208),
        icon: const Icon(Icons.add),
        label: const Text('Buat Tagihan'),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey[700],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      backgroundColor: Colors.white,
      selectedColor: const Color.fromARGB(255, 98, 195, 208),
    );
  }

  Stream<QuerySnapshot> _getBillingStream() {
    Query query = FirebaseFirestore.instance
        .collection('billing')
        .orderBy('created_at', descending: true);

    // Apply filter
    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter);
    }

    return query.snapshots();
  }

  String _getEmptyMessage() {
    switch (_selectedFilter) {
      case 'paid':
        return 'Belum ada tagihan yang dibayar';
      case 'unpaid':
        return 'Belum ada tagihan yang belum dibayar';
      case 'overdue':
        return 'Belum ada tagihan yang terlambat';
      default:
        return 'Belum ada data tagihan';
    }
  }

  Widget _buildBillingCard(Map<String, dynamic> data, String billId) {
    final status = data['status'] ?? 'unpaid';
    final amount = data['amount'] ?? 0;
    final userEmail = data['user_email'] ?? 'Email tidak tersedia';
    final dueDate = data['due_date'];

    Color statusColor;
    IconData statusIcon;
    String statusText;

    switch (status) {
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'DIBAYAR';
        break;
      case 'overdue':
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        statusText = 'TERLAMBAT';
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        statusText = 'BELUM BAYAR';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userEmail,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ID: $billId',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  avatar: Icon(statusIcon, size: 16, color: Colors.white),
                  label: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: statusColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Jumlah Tagihan',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Text(
                      'Rp ${_formatCurrency(amount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                if (dueDate != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Jatuh Tempo',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        _formatDate(dueDate),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      DateTime date;
      if (timestamp is Timestamp) {
        date = timestamp.toDate();
      } else if (timestamp is DateTime) {
        date = timestamp;
      } else {
        return 'N/A';
      }
      
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showCreateBillDialog() {
    // Dialog untuk membuat tagihan baru
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Buat Tagihan Baru'),
        content: const Text(
          'Fitur pembuatan tagihan baru akan segera hadir!\n\n'
          'Saat ini Anda dapat melihat semua tagihan yang ada dalam sistem.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}