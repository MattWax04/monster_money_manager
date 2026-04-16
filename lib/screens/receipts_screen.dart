import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyReceiptsScreen extends StatefulWidget {
  final Map<String, dynamic>? incomingReceiptData;

  const MyReceiptsScreen({super.key, this.incomingReceiptData});

  @override
  State<MyReceiptsScreen> createState() => _MyReceiptsScreenState();
}

class _MyReceiptsScreenState extends State<MyReceiptsScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // If we have incoming receipt data, save it to the database
    if (widget.incomingReceiptData != null) {
      _saveReceiptToDatabase(widget.incomingReceiptData!);
    }
  }

  Future<void> _saveReceiptToDatabase(Map<String, dynamic> receiptData) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final db = FirebaseFirestore.instance;

      // Save the receipt to receipts collection
      await db.collection('receipts').add(receiptData);
      print('Receipt saved successfully');

      // Update the budget collection with spent amounts by category
      await _updateBudgetFromReceipt(receiptData, db);
    } catch (e) {
      print('Error saving receipt: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving receipt: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _updateBudgetFromReceipt(
    Map<String, dynamic> receiptData,
    FirebaseFirestore db,
  ) async {
    // Get the receipt date
    final dateRaw = receiptData['date'] as String?;
    if (dateRaw == null) return;

    // Parse date to get month and year (format: "MM/DD/YYYY")
    final dateParts = dateRaw.split('/');
    if (dateParts.length < 2) return;

    final month = int.tryParse(dateParts[0]);
    final yearStr = dateParts[2];
    final year = int.tryParse(yearStr.substring(0, yearStr.length.clamp(1, 4)));

    if (month == null || year == null) return;

    // Get the month name
    final monthName = _getMonthName(month);
    final budgetDocId = '${monthName}_$year';

    // Group items by category and sum amounts
    final categoryTotals = <String, double>{};
    final items = receiptData['items'] as List<dynamic>? ?? [];

    for (final item in items) {
      if (item is Map<String, dynamic>) {
        final category = (item['category']?.toString() ?? 'uncategorized')
            .toLowerCase();
        final amount = (item['totalPrice'] as num?)?.toDouble() ?? 0.0;
        categoryTotals.update(
          category,
          (v) => v + amount,
          ifAbsent: () => amount,
        );
      }
    }

    // Update each category's spent amount in the budget document
    final budgetRef = db.collection('budgets').doc(budgetDocId);

    // First, set the month and year fields
    await budgetRef.set({
      'month': month,
      'year': year,
    }, SetOptions(merge: true));

    // Then update each category's spent amount
    for (final category in categoryTotals.keys) {
      final amount = categoryTotals[category]!;

      await budgetRef.set({
        category: {'spent': FieldValue.increment(amount)},
      }, SetOptions(merge: true));
    }

    print('Budget updated for $budgetDocId');
  }

  String _getMonthName(int month) {
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;

    return Material(
      color: const Color(0xFFBEE9E8),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, size: 24),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.receipt_long, size: 26),
                      const SizedBox(width: 8),
                      const Text(
                        'My Receipts',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // List of receipts
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: db.collection('receipts').snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const Center(child: Text('No receipts found'));
                        }

                        final receipts = snapshot.data!.docs;

                        return ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: receipts.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: Colors.black26),
                          itemBuilder: (context, index) {
                            final receipt =
                                receipts[index].data() as Map<String, dynamic>;
                            final name = receipt['name'] ?? 'Unknown';
                            final date = receipt['date'] ?? 'No date';
                            final items =
                                receipt['items'] as List<dynamic>? ?? [];

                            return ReceiptTile(
                              name: name,
                              date: date,
                              items: items,
                              totalAmount: receipt['totalAmount'] ?? 0,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            if (_isSaving)
              Container(
                color: Colors.black54,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class ReceiptTile extends StatefulWidget {
  final String name;
  final String date;
  final List<dynamic> items;
  final dynamic totalAmount;

  const ReceiptTile({
    required this.name,
    required this.date,
    required this.items,
    required this.totalAmount,
  });

  @override
  State<ReceiptTile> createState() => _ReceiptTileState();
}

class _ReceiptTileState extends State<ReceiptTile> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              isExpanded = !isExpanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.date,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${widget.totalAmount}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.chevron_right,
                      size: 24,
                      color: Colors.black87,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Items',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ),
                if (widget.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'No items',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        fontFamily: 'Roboto',
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: widget.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.items[index] as Map<String, dynamic>;
                      final itemName = item['name'] ?? 'Unknown';
                      final category = item['category'] ?? 'N/A';
                      final price = item['totalPrice'] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    itemName,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '\$$price',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
