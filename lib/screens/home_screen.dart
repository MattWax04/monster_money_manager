import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _outfits = [];
  bool _isLoadingOutfits = true;
  var _selectedOutfit = 0; 
  late DateTime _time;
  late int _month;
  late int _year;

  Map<String, Map<String, dynamic>> _budgets = {};
  bool _isLoadingBudgets = true;

  final List<Color> colors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.amber,
  ];


  @override
  void initState() {
    super.initState();
    _time = DateTime.now();
    _month = _time.month;
    _year = _time.year;

    _fetchOutfits();
    _fetchBudgets();

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
    List<Map<String, dynamic>> outfits = List<Map<String, dynamic>>.from(
      data['outfits']
          .where((item) => item['unlocked'] == true)
          .map((item) => Map<String, dynamic>.from(item)),
    );
    return outfits;
  }

  @override
  Widget build(BuildContext context) {

    double budgetTotal = 0;
    double spentTotal = 0;

    _budgets.forEach((category, data) {
      budgetTotal += (data['budget'] as num).toDouble();
      spentTotal += (data['spent'] as num).toDouble();
    });

    final List<_StorageData> data = listBuilder(_budgets, budgetTotal, spentTotal);
    final List<LegendItem> legend = legendBuilder(data);

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
                  const Icon(Icons.home_outlined, size: 26),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Roboto',
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  userInfo(),
                ],
              ),
            ),

            // Monthly Usage Card
            _isLoadingBudgets
              ? const CircularProgressIndicator()
              : _budgets.isEmpty
              ? const Text("No budget info found")
            : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(12),
                ),
                height: 160,
                child: Column(
                  children: [
                    const Text(
                      'Monthly Usage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('\$${budgetTotal- spentTotal} of \$${budgetTotal} Remaining'),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: 80,
                      child: SfCartesianChart(
                        margin: const EdgeInsets.all(16),
                        isTransposed: false,
                        primaryXAxis: CategoryAxis(isVisible: false),
                        primaryYAxis: NumericAxis(
                          isVisible: false,
                          minimum: 0,
                          maximum: budgetTotal,
                        ),
                        legend: const Legend(isVisible: false),
                        series: <CartesianSeries<_StorageData, String>>[
                        StackedBarSeries<_StorageData, String>(
                          dataSource: data,
                          xValueMapper: (d, _) => 'Budget',
                          yValueMapper: (d, _) => d.size,
                          pointColorMapper: (d, _) => d.color,
                        ),


                        ],
                      ),
                    ),
                    
                    Row(
                      children: [
                        const SizedBox(width: 16), // LEFT fixed padding

                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: legend
                                  .map((item) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: item,
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),

                        const SizedBox(width: 16), // RIGHT fixed padding
                      ],
                    )

                  ],
                ),
              ),
            ),

            // Egg & Background
            Expanded(
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: SvgPicture.asset(
                          'assets/images/background.svg',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 40,
                        child: _outfitInfoWidget(_selectedOutfit),
                      ),
                      // Left Button
                      Positioned(
                        left: 45,
                        bottom: 80,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 13),
                            color: const Color.fromARGB(
                              1,
                              98,
                              182,
                              203,
                            ).withValues(alpha: 0.6),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_left,
                              size: 50,
                              color: Colors.black,
                            ),
                            iconSize: 70,
                            onPressed: () {
                              setState(() {
                                _selectedOutfit--;

                                  if (_selectedOutfit < 0) {
                                    _selectedOutfit = _outfits.length -1;
                                  }
                                });
                            },
                          ),
                        ),
                      ),
                      // Right Button
                      Positioned(
                        right: 45,
                        bottom: 80,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black, width: 13),
                            color: const Color.fromARGB(
                              1,
                              98,
                              182,
                              203,
                            ).withValues(alpha: 0.6),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_right,
                              size: 50,
                              color: Colors.black,
                            ),
                            iconSize: 70,
                            onPressed: () {
                              setState(() {
                                _selectedOutfit++;

                                  if (_selectedOutfit >= _outfits.length) {
                                    _selectedOutfit = 0;
                                  }

                                });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget userInfo() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('profiles')
          .doc('main')
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text(
            'Guest',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              fontFamily: 'Roboto',
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final name = data['name'] ?? 'Guest';

        return InkWell(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
            child: Row(
              children: [
                const Icon(
                  Icons.supervised_user_circle,
                  size: 30,
                  color: Colors.black87,
                ),
                const SizedBox(width: 13),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Roboto',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _fetchBudgets() async {

    final budgets = await _loadBudgets();
    if (!mounted) return;
    setState (() {
      _budgets = budgets;
      _isLoadingBudgets = false;
    });

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


  Widget _outfitInfoWidget(int tempSelectedOutfit) {

    int selectedOutfit = tempSelectedOutfit;

    if (_isLoadingOutfits) {
      return const CircularProgressIndicator();
    }

    if (_outfits.isEmpty) {
      return const Text("No outfits found");
    }

    _selectedOutfit = selectedOutfit;

    final outfit = _outfits[selectedOutfit];

    return Image.asset(
      'assets/webp/${outfit['name']}.webp',
      width: 450,
      height: 450,
      fit: BoxFit.contain,
    );
  }

  Future<void> duplicateData(
    String newDocName,      
    String collection,     
    String toModify,   
  ) async {
    final originalDocRef = FirebaseFirestore.instance
        .collection(collection)
        .doc(toModify);

    final originalSnapshot = await originalDocRef.get();

    if (!originalSnapshot.exists) {
      return;
    }

    Map<String, dynamic> data =
        Map<String, dynamic>.from(originalSnapshot.data()!);

    data['name'] = newDocName;

    final newDocRef = FirebaseFirestore.instance
        .collection(collection)
        .doc(newDocName);

    await newDocRef.set(data);

  }
  List<LegendItem> legendBuilder(List<_StorageData> data) {
    List<LegendItem> legend = [];

    for (var item in data) {
      if (item.category != 'Budget Left'){
        legend.add(
          LegendItem(
            color: item.color,
            label: capitalize(item.category),
          ),
        );
      }
    }

    return legend;
  }

  List<_StorageData> listBuilder(Map<String, Map<String, dynamic>> data, double budgetTotal, double spentTotal){
    
    final List<_StorageData> budgetList = [];

    int i = 0;

    data.forEach((category, data) {
      Color color = colors[i % colors.length];  
      _StorageData listItem = _StorageData(category, data['spent'].toDouble(), color);
      budgetList.add(listItem);
      i++;
    });

    budgetList.add(_StorageData('Budget Left', (budgetTotal - spentTotal), Colors.grey.withValues(alpha: 0.4)));

    return budgetList;
  }

}


class _StorageData {
  final String category;
  final double size;
  final Color color;
  _StorageData(this.category, this.size, this.color);
}

class LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const LegendItem({super.key, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }
}

  String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;
