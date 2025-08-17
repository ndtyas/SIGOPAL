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
  final Map<String, String> _userCache = {};
  bool _isUpdatingPrice = false;

  Stream<QuerySnapshot> _getBillingRecordsStream() {
    Query query = FirebaseFirestore.instance.collectionGroup('billing_records');

    if (_selectedFilter != 'all') {
      query = query.where('status', isEqualTo: _selectedFilter)
                   .orderBy('createdAt', descending: true);
    } else {
    }

    return query.snapshots();
  }

  List<QueryDocumentSnapshot> _filterNonZeroRecords(
      List<QueryDocumentSnapshot> records) {
    return records.where((record) {
      final data = record.data() as Map<String, dynamic>;
      final amount = data['totalCost'] ?? 0;
      return amount != 0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<custom_auth.AuthProvider>(context);

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
            _buildFlexibleAppBar(auth),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildSummaryCard(),
                    _buildFilterChips(),
                    StreamBuilder<QuerySnapshot>(
                      stream: _getBillingRecordsStream(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _buildErrorWidget(snapshot.error.toString());
                        }

                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return _buildLoadingWidget();
                        }

                        final billingRecords = snapshot.data?.docs ?? [];
                        final filteredRecords = _filterNonZeroRecords(billingRecords);

                        if (_selectedFilter == 'all') {
                          filteredRecords.sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>;
                            final bData = b.data() as Map<String, dynamic>;
                            
                            final aCreatedAt = aData['createdAt'];
                            final bCreatedAt = bData['createdAt'];
                            
                            if (aCreatedAt == null && bCreatedAt == null) return 0;
                            if (aCreatedAt == null) return 1;
                            if (bCreatedAt == null) return -1;
                            
                            if (aCreatedAt is Timestamp && bCreatedAt is Timestamp) {
                              return bCreatedAt.compareTo(aCreatedAt);
                            }
                            
                            return 0;
                          });
                        }

                        if (filteredRecords.isEmpty) {
                          return _buildEmptyWidget();
                        }

                        return LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth > 900) {
                              return GridView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: MediaQuery.of(context).size.width * 0.05,
                                  vertical: 16,
                                ),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 1.6,
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
                              return ListView.builder(
                                padding: EdgeInsets.symmetric(
                                  horizontal: MediaQuery.of(context).size.width * 0.05,
                                  vertical: 16,
                                ),
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
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
                  ],
                ),
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
              if (constraints.maxWidth > 500) ...[
                _buildRefreshButton(),
                const SizedBox(width: 8),
                _buildLogoutButton(auth),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                  tooltip: 'Opsi Lainnya',
                  onSelected: (value) {
                    if (value == 'edit_price') {
                      _showEditPriceDialog();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit_price',
                      child: Row(
                        children: [
                          Icon(Icons.monetization_on, color: Color(0xFF62C3D0)),
                          SizedBox(width: 8),
                          Text('Ubah Harga Air'),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, size: 28),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit_price':
                        _showEditPriceDialog();
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
                    const PopupMenuItem(
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

  Widget _buildFilterChips() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.05,
        vertical: 8,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', 'Semua', Icons.list),
            const SizedBox(width: 8),
            _buildFilterChip('unpaid', 'Belum Bayar', Icons.pending),
            const SizedBox(width: 8),
            _buildFilterChip('paid', 'Sudah Bayar', Icons.check_circle),
            const SizedBox(width: 8),
            _buildFilterChip('overdue', 'Terlambat', Icons.warning),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, IconData icon) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF62C3D0)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF62C3D0))),
        ],
      ),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: const Color(0xFF62C3D0),
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFF62C3D0)),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: EdgeInsets.fromLTRB(
          MediaQuery.of(context).size.width * 0.05,
          16,
          MediaQuery.of(context).size.width * 0.05,
          8),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            spreadRadius: 2,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collectionGroup('billing_records')
            .snapshots(),
        builder: (context, billingSnapshot) {
          if (billingSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF62C3D0)),
            );
          }

          final records = billingSnapshot.data?.docs ?? [];
          final nonZeroRecords = _filterNonZeroRecords(records);

          double totalAmount = 0;
          int paidCount = 0;
          int unpaidCount = 0;
          int overdueCount = 0;

          for (var record in nonZeroRecords) {
            final data = record.data() as Map<String, dynamic>;
            final amount = data['totalCost'] ?? 0;
            final status = data['status'] ?? 'unpaid';

            totalAmount += (amount is num ? amount : 0);

            switch (status) {
              case 'paid':
                paidCount++;
                break;
              case 'overdue':
                overdueCount++;
                break;
              default:
                unpaidCount++;
            }
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('settings')
                .doc('main')
                .snapshots(),
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
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF17778F),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 800) {
                        return Row(
                          children: [
                            Expanded(
                                child: _buildSummaryItem(
                                    'Harga / M³',
                                    _formatCurrency(hargaPerCBM),
                                    Icons.monetization_on,
                                    Colors.purple)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildSummaryItem(
                                    'Total Tagihan',
                                    _formatCurrency(totalAmount),
                                    Icons.account_balance_wallet,
                                    Colors.blue)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildSummaryItem('Sudah Bayar',
                                    '$paidCount', Icons.check_circle, Colors.green)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildSummaryItem('Belum Bayar',
                                    '$unpaidCount', Icons.pending, Colors.orange)),
                            const SizedBox(width: 16),
                            Expanded(
                                child: _buildSummaryItem('Terlambat',
                                    '$overdueCount', Icons.warning, Colors.red)),
                          ],
                        );
                      } else if (constraints.maxWidth > 500) {
                        return Column(
                          children: [
                            _buildSummaryItem(
                                'Harga / M³',
                                _formatCurrency(hargaPerCBM),
                                Icons.monetization_on,
                                Colors.purple),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                    child: _buildSummaryItem(
                                        'Total',
                                        _formatCurrency(totalAmount),
                                        Icons.account_balance_wallet,
                                        Colors.blue)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _buildSummaryItem(
                                        'Bayar',
                                        '$paidCount',
                                        Icons.check_circle,
                                        Colors.green)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _buildSummaryItem('Belum',
                                        '$unpaidCount', Icons.pending, Colors.orange)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _buildSummaryItem('Telat',
                                        '$overdueCount', Icons.warning, Colors.red)),
                              ],
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildSummaryItem(
                                'Harga / M³',
                                _formatCurrency(hargaPerCBM),
                                Icons.monetization_on,
                                Colors.purple),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                    child: _buildSummaryItem(
                                        'Total',
                                        _formatCurrency(totalAmount),
                                        Icons.account_balance_wallet,
                                        Colors.blue)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _buildSummaryItem(
                                        'Bayar',
                                        '$paidCount',
                                        Icons.check_circle,
                                        Colors.green)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                    child: _buildSummaryItem('Belum',
                                        '$unpaidCount', Icons.pending, Colors.orange)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: _buildSummaryItem('Telat',
                                        '$overdueCount', Icons.warning, Colors.red)),
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

  Widget _buildRefreshButton() {
    return IconButton(
      icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
      onPressed: () => setState(() {
        _userCache.clear();
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();

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

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.05),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.white),
              const SizedBox(height: 16),
              const Text(
                'Terjadi kesalahan saat memuat data.',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => setState(() {}),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF62C3D0),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    textStyle: const TextStyle(fontSize: 16)),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48.0),
      child: Center(
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
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Center(
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
    final amount = data['totalCost'] ?? 0;
    final description = data['nodeName'] ?? 'Tagihan';
    final dueDate = data['endDate'];
    final statusInfo = _getStatusInfo(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 8,
            spreadRadius: 2,
            offset: Offset(0, 4),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF17778F)),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    FutureBuilder<String>(
                      future: _getUserName(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text('Memuat...',
                              style: TextStyle(color: Colors.grey, fontSize: 12));
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
                    child: Row(children: [
                      Icon(Icons.info_outline, color: Color(0xFF62C3D0), size: 18),
                      SizedBox(width: 8),
                      Text('Detail')
                    ]),
                  ),
                  const PopupMenuItem(
                    value: 'edit_status',
                    child: Row(children: [
                      Icon(Icons.edit, color: Color(0xFF62C3D0), size: 18),
                      SizedBox(width: 8),
                      Text('Ubah Status')
                    ]),
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
                    if (dueDate != null) ...[
                      const SizedBox(height: 8),
                      _buildDueDateSection(dueDate)
                    ],
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
                Text(statusInfo['text'],
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
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
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF17778F)),
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
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF17778F)),
        ),
      ],
    );
  }

  Map<String, dynamic> _getStatusInfo(String status) {
    switch (status) {
      case 'paid':
        return {
          'color': Colors.green,
          'icon': Icons.check_circle,
          'text': 'DIBAYAR'
        };
      case 'overdue':
        return {'color': Colors.red, 'icon': Icons.warning, 'text': 'TERLAMBAT'};
      default:
        return {
          'color': Colors.orange,
          'icon': Icons.pending,
          'text': 'BELUM BAYAR'
        };
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

  void _showBillDetails(BuildContext context, Map<String, dynamic> data,
      String recordId, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.receipt_long, color: Color(0xFF62C3D0)),
          SizedBox(width: 8),
          Text('Detail Tagihan')
        ]),
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
                              Text(snapshot.data ?? 'Memuat...',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF17778F))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('ID: $userId',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      );
                    },
                  ),
                ),
                _buildDetailRow('Node Name', data['nodeName'] ?? 'N/A'),
                _buildDetailRow('Usage (M³)', '${data['usage'] ?? 0}'),
                _buildDetailRow('Meter Awal', '${data['meterAwal'] ?? 0}'),
                _buildDetailRow('Meter Akhir', '${data['meterAkhir'] ?? 0}'),
                _buildDetailRow('Harga per M³', _formatCurrency(data['hargaPerCBM'] ?? 0)),
                _buildDetailRow('Total Cost', _formatCurrency(data['totalCost'] ?? 0)),
                _buildDetailRow('Status', _getStatusText(data['status'] ?? 'unpaid')),
                _buildDetailRow('Start Date', _formatDate(data['startDate'])),
                _buildDetailRow('End Date', _formatDate(data['endDate'])),
                _buildDetailRow('Created At', _formatDate(data['createdAt'])),
                const SizedBox(height: 8),
                Text('Record ID: $recordId',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontFamily: 'monospace')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'))
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text('$label:',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF17778F)))),
          Expanded(
              child: Text(value, style: const TextStyle(color: Colors.black87))),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'Sudah Dibayar';
      case 'overdue':
        return 'Terlambat';
      default:
        return 'Belum Dibayar';
    }
  }

  void _showEditStatusDialog(BuildContext context, Map<String, dynamic> data,
      String recordId, String userId) {
    String selectedStatus = data['status'] ?? 'unpaid';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(children: [
                Icon(Icons.edit, color: Color(0xFF62C3D0)),
                SizedBox(width: 8),
                Text('Ubah Status')
              ]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8)),
                    child: FutureBuilder<String>(
                      future: _getUserName(userId),
                      builder: (context, snapshot) {
                        const textStyle = TextStyle(color: Colors.black87);

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('User: ${snapshot.data ?? 'Memuat...'}', style: textStyle),
                            const SizedBox(height: 4),
                            Text('Tagihan: ${data['nodeName'] ?? 'N/A'}', style: textStyle),
                            const SizedBox(height: 4),
                            Text('Jumlah: ${_formatCurrency(data['totalCost'])}', style: textStyle),
                          ],
                        );
                      },
                    ),
                  ),
                  RadioListTile<String>(
                    title: const Text('Belum Dibayar'),
                    value: 'unpaid',
                    groupValue: selectedStatus,
                    onChanged: (value) => value != null
                        ? setDialogState(() => selectedStatus = value)
                        : null,
                  ),
                  RadioListTile<String>(
                    title: const Text('Sudah Dibayar'),
                    value: 'paid',
                    groupValue: selectedStatus,
                    onChanged: (value) => value != null
                        ? setDialogState(() => selectedStatus = value)
                        : null,
                  ),
                  RadioListTile<String>(
                    title: const Text('Terlambat'),
                    value: 'overdue',
                    groupValue: selectedStatus,
                    onChanged: (value) => value != null
                        ? setDialogState(() => selectedStatus = value)
                        : null,
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateBillStatus(userId, recordId, selectedStatus);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF62C3D0),
                      foregroundColor: Colors.white),
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditPriceDialog() {
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('settings')
              .doc('main')
              .snapshots(),
          builder: (context, snapshot) {
            final bool isLoading = snapshot.connectionState == ConnectionState.waiting;
            String currentPriceStr = "0";

            if (!isLoading && snapshot.hasData && snapshot.data!.exists) {
              final data = snapshot.data!.data() as Map<String, dynamic>;
              final currentPrice = (data['hargaPerCBM'] as num?)?.toDouble() ?? 0.0;
              currentPriceStr = currentPrice.toStringAsFixed(0);
              if (priceController.text.isEmpty) {
                priceController.text = currentPriceStr;
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth > 600;

                    return Container(
                      padding: EdgeInsets.all(isWideScreen ? 32 : 24),
                      child: Form(
                        key: formKey,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      color: Color(0x1A62C3D0),
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                    ),
                                    child: const Icon(
                                      Icons.monetization_on,
                                      color: Color(0xFF62C3D0),
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Pengaturan Harga Air',
                                          style: TextStyle(
                                            fontSize: isWideScreen ? 24 : 20,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF17778F),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Ubah harga per meter kubik',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0x1A62C3D0), Color(0x0D62C3D0)],
                                  ),
                                  borderRadius: BorderRadius.all(Radius.circular(16)),
                                  border: Border.fromBorderSide(BorderSide(color: Color(0x3362C3D0))),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.info_outline, color: Color(0xFF62C3D0), size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Harga Saat Ini',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatCurrency(double.tryParse(currentPriceStr) ?? 0),
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF17778F),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Harga Baru per M³',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: priceController,
                                    enabled: !isLoading && !_isUpdatingPrice,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                    decoration: InputDecoration(
                                      prefixText: 'Rp ',
                                      prefixStyle: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF62C3D0),
                                      ),
                                      hintText: 'Masukkan harga baru',
                                      helperText: 'Contoh: 2000 (tanpa titik atau koma)',
                                      helperStyle: TextStyle(color: Colors.grey[600]),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF62C3D0), width: 2),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.grey[300]!),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Harga tidak boleh kosong';
                                      }
                                      final numValue = double.tryParse(value);
                                      if (numValue == null) {
                                        return 'Masukkan angka yang valid';
                                      }
                                      if (numValue < 0) {
                                        return 'Harga tidak boleh negatif';
                                      }
                                      if (numValue > 1000000) {
                                        return 'Harga terlalu tinggi (maksimal 1 juta)';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton(
                                      onPressed: _isUpdatingPrice ? null : () => Navigator.pop(context),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: const Text('Batal', style: TextStyle(fontSize: 16)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 2,
                                    child: ElevatedButton(
                                      onPressed: (isLoading || _isUpdatingPrice)
                                          ? null
                                          : () {
                                              if (formKey.currentState!.validate()) {
                                                final newPrice = double.parse(priceController.text);
                                                _updateWaterPrice(newPrice);
                                                Navigator.pop(context);
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF62C3D0),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: _isUpdatingPrice
                                          ? const Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                                SizedBox(width: 12),
                                                Text('Menyimpan...', style: TextStyle(fontSize: 16)),
                                              ],
                                            )
                                          : const Text(
                                              'Simpan',
                                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _updateWaterPrice(double newPrice) async {
    setState(() {
      _isUpdatingPrice = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('settings')
          .doc('main')
          .set({'hargaPerCBM': newPrice}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Harga berhasil diupdate!',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Harga baru: ${_formatCurrency(newPrice)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Gagal mengupdate harga',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Error: $e',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPrice = false;
        });
      }
    }
  }

  Future<void> _updateBillStatus(String userId, String recordId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('billing_records')
          .doc(recordId)
          .update({'status': newStatus});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Status berhasil diubah ke ${_getStatusText(newStatus)}'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showLogoutDialog(BuildContext context, custom_auth.AuthProvider auth) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 8),
          Text('Konfirmasi Logout')
        ]),
        content: const Text('Apakah Anda yakin ingin keluar dari akun admin?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);

              navigator.pop();

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
              );

              try {
                await auth.signOut();
                if (!mounted) return;
                navigator.pop();
                navigator.pushReplacementNamed('/welcome');
              } catch (e) {
                if (!mounted) return;
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                      content: Text('Error saat logout: $e'),
                      backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}