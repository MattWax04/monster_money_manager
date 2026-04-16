import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';


class BudgetScreen extends StatefulWidget {

  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {

  late DateTime _time;
  late int _month;
  late int _year;
  final textController = TextEditingController();

  Map<String, Map<String, dynamic>> _budgets = {};
  bool _isLoadingBudgets = true;


  @override
  void initState() {
    super.initState();
    _time = DateTime.now();
    _month = _time.month;
    _year = _time.year;
    _fetchBudgets();
  }


  @override
  Widget build(BuildContext context) {

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
                  const Icon(Icons.receipt_long, size: 26),
                  const SizedBox(width: 8),
                  const Text(
                    'Budget Preferences',
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
            _isLoadingBudgets
              ? const CircularProgressIndicator()
              : _budgets.isEmpty
              ? const Text("No budget info found")
              
            // List of receipts
            : Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: 
                ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _budgets.length,
                  separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Colors.black26),
                  itemBuilder: (context, index) {
                    final key = _budgets.keys.elementAt(index);        
                    final data = _budgets[key]!;                     

                    final budget = data['budget'];
                    final spent = data['spent'];

                    return InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          builder: (context) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Edit ${capitalize(key)} Budget', 
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  SizedBox(height: 16),
                                  TextField(
                                    controller: textController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: '\$${budget.toStringAsFixed(2)}',
                                      prefix: Text("\$"),
                                    )
                                  ),
                                  SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final newText = textController.text.trim();
                                      if (newText.isEmpty) return;

                                      await changeBudget(key, newText); 
                                      await _fetchBudgets();            

                                      textController.clear();

                                      if (mounted) {
                                        Navigator.pop(context);       
                                      }
                                    },
                                    child: Text('Save'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
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
                                  // Category name
                                  Text(
                                    capitalize(key),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Roboto',
                                    ),
                                  ),
                                  const SizedBox(height: 2),

                                  // Budget and spent
                                  Text(
                                      'Budget: \$${budget.toStringAsFixed(2)} • Spent: \$${spent.toString()}',
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
                              Icons.edit,
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

    @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }


  Future<void> _fetchBudgets() async {
    final budgets = await _loadBudgets();
    if (!mounted) return;
    setState (() {
      _budgets = budgets;
      _isLoadingBudgets = false;
    });
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

  changeBudget(String name, String strValue) async{
    
    print(strValue);

    try {
      double value = double.parse(strValue);

      print(value);
      if (!hasTwoDecimalPlaces(value)){
        return;
      }

      String month = monthName(_month);

      final doc = FirebaseFirestore.instance
        .collection('budgets')
        .doc('${month}_${_year}');

      await doc.update({
        '${name}.budget' : value
      });

      print("Updated ${name}");

    } on FormatException {
      return;
    }


  }

  String monthName(int monthNumber) {
    return DateFormat('MMMM').format(DateTime(0, monthNumber)).toLowerCase();
  }

  String capitalize(String s) =>
    s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  bool hasTwoDecimalPlaces(double number) {
    String formattedNumber = number.toStringAsFixed(2);
    return formattedNumber.contains(RegExp(r'\.\d{2}$'));
  }


}