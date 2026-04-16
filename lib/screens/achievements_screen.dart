import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreen();
}

class _AchievementsScreen extends State<AchievementsScreen> {
  bool _isLoadingOutfits = true;
  late DateTime _time;
  late int _month;
  late int _year;
  List<Map<String, dynamic>> _outfits = [];
  int? _curAchievement;

  Map<String, Map<String, dynamic>> _budgets = {};
  bool _isLoadingBudgets = true;

  @override
  void initState() {
    super.initState();

    _time = DateTime.now();
    _month = _time.month;
    _year = _time.year;

    _fetchOutfits();
    _fetchBudgets();
  }

  @override
  Widget build(BuildContext context) {
    List achievements = achievementBuilder();
    if (_curAchievement == null ||
        _curAchievement! < 0 ||
        _curAchievement! >= _outfits.length) {
      return const Material(
        color: Color(0xFFBEE9E8),
        child: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    if (_isLoadingOutfits || _isLoadingBudgets) {
      return const Material(
        color: Color(0xFFBEE9E8),
        child: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    String curAchName = _outfits[_curAchievement!]['unlock_method'];
    double curAchSpent =
        (_budgets[curAchName]?['spent'] as num?)?.toDouble() ?? 0;
    double curAchBudget =
        (_budgets[curAchName]?['budget'] as num?)?.toDouble() ?? 0;
    List<ChartData> chartData = [
      ChartData(
        _outfits[_curAchievement!]['unlock_method'],
        curAchSpent,
        curAchBudget - curAchSpent,
      ),
    ];

    curAchSpent = (_budgets[curAchName]!['spent'] as num).toDouble();

    curAchBudget = (_budgets[curAchName]!['budget'] as num).toDouble();

    return Material(
      color: const Color(0xFFBEE9E8),
      child: SafeArea(
        child: Scaffold(
          body: Column(
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
                    const Icon(Icons.emoji_events, size: 26),
                    const SizedBox(width: 8),
                    const Text(
                      'My Achievements',
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

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    itemCount: achievements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = achievements[index];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['month']!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item['achievements']!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Unlocked',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black54,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item['unlocked']!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This Month:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Roboto',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Spend less than \$${curAchBudget.toStringAsFixed(2)} on ${capitalize(_outfits[_curAchievement!]['unlock_method'])}',
                      style: TextStyle(fontSize: 14, fontFamily: 'Roboto'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: 180,
                            child: SfCartesianChart(
                              margin: const EdgeInsets.all(8),
                              legend: Legend(isVisible: true),
                              primaryXAxis: CategoryAxis(isVisible: false),
                              primaryYAxis: NumericAxis(
                                isVisible: false,
                                minimum: 0,
                                maximum: curAchBudget, // total budget
                              ),
                              series: <CartesianSeries>[
                                StackedBarSeries<ChartData, String>(
                                  dataSource: chartData,
                                  xValueMapper: (d, _) => d.category,
                                  yValueMapper: (d, _) => d.spent,
                                  name: 'Money spent',
                                  color: Colors.red,
                                ),
                                StackedBarSeries<ChartData, String>(
                                  dataSource: chartData,
                                  xValueMapper: (d, _) => d.category,
                                  yValueMapper: (d, _) => d.remaining,
                                  name: 'Money remaining',
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${capitalize(monthName(_month))} ${capitalize(_outfits[_curAchievement!]['unlock_method'])} Budget',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                              Text(
                                '\$${curAchSpent.toStringAsFixed(2)}/\$${curAchBudget.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Roboto',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Image.asset(
              //   'assets/images/annoyedmonster.png',
              //   width: 100,
              //   height: 100,
              // ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _fetchBudgets() async {
    final budgets = await _loadBudgets();
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
      _isLoadingBudgets = false;
    });

    print(_budgets);
  }

  Future<void> _fetchOutfits() async {
    final outfits = await _loadOutfits();
    if (!mounted) return;
    setState(() {
      _outfits = outfits;
      _isLoadingOutfits = false;
    });
  }

  Future<List<Map<String, dynamic>>> _loadOutfits() async {
    final doc = await FirebaseFirestore.instance
        .collection('user_unlocks')
        .doc('unlocks')
        .get();

    if (!doc.exists) return [];

    final data = doc.data() as Map<String, dynamic>;

    return List<Map<String, dynamic>>.from(data['outfits']);
  }

  List achievementBuilder() {
    List<Map<String, dynamic>> achievements = [];

    for (int i = 1; i < _outfits.length; i++) {
      final outfit = _outfits[i];

      if (outfit['unlocked'] == true) {
        achievements.add({
          'month': _formatMonthYear(outfit['unlock_time']),
          'achievements': outfit['unlock_method'],
          'unlocked': outfit['name'],
        });
      } else {
        _curAchievement ??= i;
      }
    }

    return achievements;
  }

  String _formatMonthYear(String monthYearStr) {
    // Assuming format is "month_year" like "september_2025"
    final parts = monthYearStr.split('_');
    if (parts.length == 2) {
      final month = capitalize(parts[0]);
      final year = parts[1];
      return '$month $year';
    }
    return monthYearStr;
  }

  String monthName(int monthNumber) {
    return DateFormat('MMMM').format(DateTime(0, monthNumber)).toLowerCase();
  }

  Future<Map<String, Map<String, dynamic>>> _loadBudgets() async {
    String month = monthName(_month);

    final doc = await FirebaseFirestore.instance
        .collection('budgets')
        .doc('${month}_${_year}')
        .get();

    if (!doc.exists) return {};

    final data = doc.data() as Map<String, dynamic>;

    final result = <String, Map<String, dynamic>>{};

    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        result[key] = Map<String, dynamic>.from(value);
      }
    });

    return result;
  }
}

class ChartData {
  final String category;
  final num spent;
  final num remaining;
  ChartData(this.category, this.spent, this.remaining);
}

String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
