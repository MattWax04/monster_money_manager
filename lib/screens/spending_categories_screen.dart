import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

String _normalizeCategory(String value) => value.trim().toLowerCase();

class SpendingCategoriesScreen extends StatefulWidget {
  final void Function(String category)? onCategoryTap;
  const SpendingCategoriesScreen({super.key, this.onCategoryTap});

  @override
  State<SpendingCategoriesScreen> createState() =>
      _SpendingCategoriesScreenState();
}

class _SpendingCategoriesScreenState extends State<SpendingCategoriesScreen> {
  static const _bg = Color.fromARGB(255, 190, 233, 232);
  final DateTime _now = DateTime.now();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  String? _error;
  List<_CategorySpending> _categories = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final budgetData = await _fetchBudgetDoc();
      final receiptEntries = await _loadReceiptEntries();
      final parsed = _parseCategories(budgetData, receiptEntries);

      setState(() {
        _categories = parsed;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Unable to load spending categories.';
      });
    }
  }

  Future<Map<String, dynamic>> _fetchBudgetDoc() async {
    final docId = _docIdForMonth(_now);
    final docRef = _firestore.collection('budgets').doc(docId);
    final doc = await docRef.get();
    if (doc.exists && doc.data() != null) {
      return doc.data()!;
    }

    // Fallback: return first document in budgets collection.
    final fallback = await _firestore.collection('budgets').limit(1).get();
    if (fallback.docs.isNotEmpty && fallback.docs.first.data().isNotEmpty) {
      return fallback.docs.first.data();
    }

    return {};
  }

  Future<Map<String, _ReceiptGroup>> _loadReceiptEntries() async {
    final receiptsSnapshot = await _firestore.collection('receipts').get();
    final Map<String, _ReceiptGroup> byCategory = {};

    for (final doc in receiptsSnapshot.docs) {
      final data = doc.data();
      final dateRaw = data['date']?.toString();
      final date = _parseReceiptDate(dateRaw);
      final items = data['items'];
      if (items is List) {
        for (final item in items) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final category = map['category']?.toString() ?? 'Uncategorized';
            final normalized = _normalizeCategory(category);
            final amount =
                (map['totalAmount'] as num?)?.toDouble() ??
                (map['totalPrice'] as num?)?.toDouble() ??
                0;
            final entry = _SpendingEntry(
              amount: amount,
              date: date ?? _now,
              note: map['name']?.toString(),
            );
            final group = byCategory.putIfAbsent(
              normalized,
              () => _ReceiptGroup(displayName: category, entries: []),
            );
            group.entries.add(entry);
          }
        }
      }
    }

    return byCategory;
  }

  DateTime? _parseReceiptDate(String? raw) {
    if (raw == null) return null;
    // Accept formats like "25/11/2025" or ISO.
    if (raw.contains('/')) {
      final parts = raw.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]) ?? 1;
        final month = int.tryParse(parts[1]) ?? 1;
        // Handle strings like "2017 12:16 PM" by trimming to first 4 digits.
        final yearString = parts[2].trim();
        final year =
            int.tryParse(
              yearString.substring(0, yearString.length.clamp(1, 4)),
            ) ??
            _now.year;
        return DateTime(year, month, day);
      }
    }
    return DateTime.tryParse(raw);
  }

  List<_CategorySpending> _parseCategories(
    Map<String, dynamic> raw,
    Map<String, _ReceiptGroup> receiptEntries,
  ) {
    final parsed = <_CategorySpending>[];
    final seenNormalized = <String>{};

    raw.forEach((key, value) {
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        final cat = _CategorySpending.fromBudgetMap(
          key,
          map,
          now: _now,
          receiptEntries: receiptEntries,
        );
        parsed.add(cat);
        seenNormalized.add(_normalizeCategory(cat.name));
      }
    });

    // Include categories that only appear in receipts so they always show up.
    receiptEntries.forEach((catName, entries) {
      if (seenNormalized.contains(catName)) return;
      parsed.add(
        _CategorySpending(
          name: entries.displayName,
          budget: 0,
          entries: entries.entries,
          rawForMonth: const {},
          year: _now.year,
          month: _now.month,
          reportedSpent: 0,
        ),
      );
    });

    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 24),
                    splashRadius: 22,
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.storage_outlined, size: 26),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Spending Categories',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      const Text(
                        'All Time',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Roboto',
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _loadCategories,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open, size: 42),
            const SizedBox(height: 8),
            const Text(
              'No categories yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            const Text(
              'As soon as your Firebase JSON tree is populated\n'
              'you will see live budgets and totals here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _loadCategories,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      itemCount: _categories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final cat = _categories[index];
        final spent = cat.totalSpent;
        final spentLabel = _formatCurrency(spent);
        final budgetLabel = cat.budget > 0 ? _formatCurrency(cat.budget) : '-';
        final remaining = cat.budget > 0 ? cat.budget - spent : null;

        return Card(
          elevation: 1.5,
          color: Colors.white.withValues(alpha: 0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            onExpansionChanged: (open) {
              if (open && widget.onCategoryTap != null) {
                widget.onCategoryTap!(cat.name);
              }
            },
            title: Text(
              _capitalize(cat.name),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'Roboto',
              ),
            ),
            subtitle: Text(
              'Spent $spentLabel${cat.budget > 0 ? ' of $budgetLabel' : ''}',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontFamily: 'Roboto',
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  budgetLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Roboto',
                  ),
                ),
                if (remaining != null)
                  Text(
                    remaining >= 0
                        ? '${_formatCurrency(remaining)} left'
                        : '${_formatCurrency(remaining.abs())} over',
                    style: TextStyle(
                      fontSize: 12,
                      color: remaining >= 0
                          ? Colors.green[800]
                          : Colors.red[700],
                      fontFamily: 'Roboto',
                    ),
                  ),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BudgetProgress(cat: cat),
                    const SizedBox(height: 10),
                    _InsightChip(text: cat.insight),
                    const SizedBox(height: 12),
                    _MonthlyBreakdown(cat: cat),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatCurrency(double amount) => '\$${amount.toStringAsFixed(2)}';

  String _capitalize(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String _docIdForMonth(DateTime date) {
    // Match the doc ID format used elsewhere: "<month>_<year>", all lowercase.
    final monthName = _monthName(date.month).toLowerCase();
    return '${monthName}_${date.year}';
  }
}

class _BudgetProgress extends StatelessWidget {
  final _CategorySpending cat;
  const _BudgetProgress({required this.cat});

  @override
  Widget build(BuildContext context) {
    final spent = cat.totalSpent;
    final percent = cat.budget <= 0
        ? 0.0
        : (spent / cat.budget).clamp(0.0, 1.2);
    final overBudget = cat.budget > 0 && spent > cat.budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'All receipts: \$${spent.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              cat.budget > 0
                  ? '${((spent / cat.budget) * 100).clamp(0, 999).toStringAsFixed(1)}% of budget'
                  : 'No budget set',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: cat.budget > 0 ? percent.clamp(0, 1) : 0,
            minHeight: 10,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              overBudget ? Colors.red : Colors.teal,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthlyBreakdown extends StatelessWidget {
  final _CategorySpending cat;
  const _MonthlyBreakdown({required this.cat});

  @override
  Widget build(BuildContext context) {
    final entries = cat.entriesSorted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Receipt activity',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '${entries.length} purchase${entries.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Text(
            'No receipts logged yet.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          )
        else
          Column(
            children: entries.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.receipt_long, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.note ?? 'Purchase',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(e.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${e.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[(date.month - 1).clamp(0, 11)]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }
}

class _InsightChip extends StatelessWidget {
  final String text;
  const _InsightChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.teal, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _SpendingEntry {
  final double amount;
  final DateTime date;
  final String? note;

  _SpendingEntry({required this.amount, required this.date, this.note});

  factory _SpendingEntry.fromMap(Map<String, dynamic> map) {
    final amount = (map['amount'] as num?)?.toDouble() ?? 0;
    final dateRaw = map['date'] ?? map['timestamp'] ?? map['time'];
    final note = map['note']?.toString();

    DateTime date = DateTime.now();
    if (dateRaw is int) {
      // Accept both seconds and milliseconds since epoch.
      date = dateRaw.toString().length <= 10
          ? DateTime.fromMillisecondsSinceEpoch(dateRaw * 1000)
          : DateTime.fromMillisecondsSinceEpoch(dateRaw);
    } else if (dateRaw is String) {
      date = DateTime.tryParse(dateRaw) ?? date;
    }

    return _SpendingEntry(amount: amount, date: date, note: note);
  }
}

class _CategorySpending {
  final String name;
  final double budget;
  final List<_SpendingEntry> entries;
  final Map<String, dynamic> rawForMonth;
  final int year;
  final int month;
  final double reportedSpent;

  _CategorySpending({
    required this.name,
    required this.budget,
    required this.entries,
    required this.rawForMonth,
    required this.year,
    required this.month,
    required this.reportedSpent,
  });

  factory _CategorySpending.fromBudgetMap(
    String key,
    Map<String, dynamic> map, {
    required DateTime now,
    required Map<String, _ReceiptGroup> receiptEntries,
  }) {
    final budget =
        (map['budget'] as num?)?.toDouble() ??
        (map['limit'] as num?)?.toDouble() ??
        0;
    final reportedSpent = (map['spent'] as num?)?.toDouble() ?? 0;
    final name = map['category']?.toString() ?? key;
    final normalized = _normalizeCategory(name);
    final entries =
        receiptEntries[normalized]?.entries ?? const <_SpendingEntry>[];

    return _CategorySpending(
      name: name,
      budget: budget,
      entries: entries,
      rawForMonth: map,
      year: now.year,
      month: now.month,
      reportedSpent: reportedSpent,
    );
  }

  double get totalSpent {
    return entries.fold(0, (sum, e) => sum + e.amount.toDouble());
  }

  List<_SpendingEntry> get entriesSorted =>
      List<_SpendingEntry>.from(entries)
        ..sort((a, b) => b.date.compareTo(a.date));

  String get insight {
    final monthSpend = totalSpent;
    if (budget <= 0) {
      return 'No budget set for $name yet. Add a limit in Firebase to see pacing.';
    }
    final pct = (monthSpend / budget) * 100;
    if (pct < 50) {
      return 'You have used ${pct.toStringAsFixed(1)}% of your $name budget — lots of breathing room.';
    }
    if (pct < 90) {
      return 'You are on track, at ${pct.toStringAsFixed(1)}% of your $name budget.';
    }
    if (pct <= 110) {
      return 'Careful — ${pct.toStringAsFixed(1)}% of your $name budget is gone. Consider pausing non-essentials.';
    }
    return 'Over budget for $name. Try to skip this category for the rest of the month.';
  }
}

class _ReceiptGroup {
  final String displayName;
  final List<_SpendingEntry> entries;

  _ReceiptGroup({required this.displayName, required this.entries});
}
