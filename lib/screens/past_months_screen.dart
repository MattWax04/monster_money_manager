import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PastMonthsScreen extends StatefulWidget {
  const PastMonthsScreen({super.key});

  @override
  State<PastMonthsScreen> createState() => _PastMonthsScreenState();
}

class _PastMonthsScreenState extends State<PastMonthsScreen> {
  List<Map<String, dynamic>> _pastMonths = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await _getPastBudgets();
    setState(() {
      _pastMonths = data;
    });
  }

  String monthName(int m) {
    const names = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];
    return names[m - 1];
  }

  double computeTotalSpent(Map<String, dynamic> doc) {
    double total = 0.0;

    const categories = [
      "entertainment",
      "essentials",
      "food",
      "medical",
      "misc",
      "transportation",
      "utilities",
    ];

    for (var cat in categories) {
      if (doc[cat] != null && doc[cat]["spent"] != null) {
        total += (doc[cat]["spent"] as num).toDouble();
      }
    }

    return total;
  }

  Future<List<Map<String, dynamic>>> _getPastBudgets() async {
    final db = FirebaseFirestore.instance;

    DateTime date = DateTime.now();

    final CollectionReference budgets = db.collection("budgets");
    print(db.collection("budgets"));

    QuerySnapshot pastMonthsQuery = await budgets.get();

    List<Map<String, dynamic>> result = [];

    for (var doc in pastMonthsQuery.docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Extract month and year with validation
      final month = data["month"];
      final year = data["year"];

      // Skip if month/year are missing or invalid
      if (month == null || year == null) continue;

      final monthInt = (month is int) ? month : int.tryParse(month.toString());
      final yearInt = (year is int) ? year : int.tryParse(year.toString());

      // Validate month is in range 1-12
      if (monthInt == null || monthInt < 1 || monthInt > 12 || yearInt == null)
        continue;

      final total = computeTotalSpent(data);

      result.add({"month": monthInt, "year": yearInt, "total": total});
    }

    result.sort((a, b) {
      final aDate = DateTime(a["year"], a["month"]);
      final bDate = DateTime(b["year"], b["month"]);
      return bDate.compareTo(aDate);
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final monthlySummary = _pastMonths;

    return Material(
      color: const Color(0xFFBEE9E8),
      child: SafeArea(
        child: Column(
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
                  const Icon(Icons.calendar_month, size: 26),
                  const SizedBox(width: 8),
                  const Text(
                    'Past Months',
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

            // Monthly summaries
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: monthlySummary.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Colors.black26),
                  itemBuilder: (context, index) {
                    final m = monthlySummary[index];
                    final year = m['year'] is int
                        ? (m['year'] < 100 ? 2000 + m['year'] : m['year'])
                        : m['year'];
                    final monthStr = "${monthName(m['month'])} $year";
                    final totalStr = m["total"].toStringAsFixed(2);
                    return InkWell(
                      onTap: () {
                        Navigator.pop(context, monthStr);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    monthStr,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Total spent: \$${totalStr}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 24,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
