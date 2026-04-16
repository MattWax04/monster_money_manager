import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:monster_money_manager/screens/achievements_screen.dart';
import 'package:monster_money_manager/screens/receipts_screen.dart';
import 'package:monster_money_manager/screens/past_months_screen.dart';
import 'package:monster_money_manager/screens/spending_categories_screen.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../components/navbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  String? _selectedMonth;
  List<Map<String, dynamic>> _monthlyAmounts = [];

  @override
  void initState() {
    super.initState();
    _selectedMonth ??= "November 2025";
    _fetchMonthlyData();
  }

  Future<void> _fetchMonthlyData() async {
    final amounts = await _loadMonthlyData();
    if (!mounted) return;
    setState(() {
      _monthlyAmounts = amounts;
    });
  }

  Future<List<Map<String, dynamic>>> _loadMonthlyData() async {
    String monthId = _selectedMonth!.toLowerCase();
    monthId = monthId.replaceAll(' ', '_');
    print('Selected month: "$_selectedMonth"');
    print('MonthId for doc: "$monthId"');
    final doc = await FirebaseFirestore.instance
        .collection('budgets')
        .doc(monthId)
        .get();

    if (!doc.exists) return [];

    final data = doc.data() as Map<String, dynamic>;

    List<Map<String, dynamic>> result = [];

    data.forEach((category, value) {
      if (value is Map<String, dynamic>) {
        // value already contains spent and budget
        result.add({'category': category, ...value});
      } else if (value is num) {
        // value is just a number, wrap it into a map
        result.add({'category': category, 'spent': value});
      }
    });

    return result;
  }

  // Dummy data for November 2025
  List<_ChartData> _getMonthlyData(List<Map<String, dynamic>>? values) {
    if (values != null) {
      if (values.isNotEmpty) {
        values.removeWhere((map) => map['category'] == 'year');
        values.removeWhere((map) => map['category'] == 'month');
        List<_ChartData> finalValues = values.map((map) {
          final category = map['category'] as String; // category name
          final spent = map['spent'] as num; // spent amount
          return _ChartData(_capitalize(category), double.parse(spent.toDouble().toStringAsFixed(2)));
        }).toList();

        return finalValues;
      }
    }
    // Default data
    return [
      _ChartData('Entertainment', 123),
      _ChartData('Essentials', 116),
      _ChartData('Food', 160),
      _ChartData('Medical', 120),
      _ChartData('Misc', 78),
      _ChartData('Transportation', 131),
      _ChartData('Utilities', 190),
    ];
  }

  String _capitalize(String s) =>
      s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  @override
  Widget build(BuildContext context) {
    //FutureBuilder
    final spendingData = _getMonthlyData(_monthlyAmounts);

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
                  const Icon(Icons.storage_outlined, size: 26),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Data',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Roboto',
                        ),
                      ),
                      if (_selectedMonth != null)
                        Text(
                          _selectedMonth!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Roboto',
                            color: Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Donut Chart
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                height: 380,
                child: SfCircularChart(
                  margin: const EdgeInsets.all(8),
                  legend: Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                  ),
                  series: <CircularSeries>[
                    DoughnutSeries<_ChartData, String>(
                      dataSource: spendingData,
                      xValueMapper: (data, _) => data.category,
                      yValueMapper: (data, _) => data.value,
                      dataLabelMapper: (data, _) => '${data.value.toStringAsFixed(2)}',
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: true,
                        labelPosition: ChartDataLabelPosition.inside,
                      ),
                      innerRadius: '50%',
                      radius: '95%',
                      pointColorMapper: (datum, index) {
                        final colors = [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.purple,
                          Colors.indigo,
                        ];
                        return colors[index % colors.length];
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 0),

            // List Options
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildOption(context, 'My Receipts'),
                    _buildOption(context, 'Spending Categories'),
                    _buildOption(context, 'Past Months'),
                    _buildOption(context, 'My Achievements'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, String title) {
    return InkWell(
      onTap: () async {
        if (title == 'My Receipts') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyReceiptsScreen()),
          );
        } else if (title == 'Past Months') {
          final selectedMonth = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (context) => const PastMonthsScreen()),
          );
          if (selectedMonth != null) {
            setState(() {
              _selectedMonth = selectedMonth;
            });
            _fetchMonthlyData();
          }
        } else if (title == 'Spending Categories') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SpendingCategoriesScreen(),
            ),
          );
        } else if (title == 'My Achievements') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AchievementsScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Roboto',
                ),
              ),
            ),
            const Icon(Icons.chevron_right, size: 24, color: Colors.black87),
          ],
        ),
      ),
    );
  }
}

class _ChartData {
  final String category;
  final double value;
  _ChartData(this.category, this.value);
}
