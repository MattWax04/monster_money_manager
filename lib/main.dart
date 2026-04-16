import 'package:flutter/material.dart';
import 'components/navbar.dart';
import 'screens/scan_receipt_screen.dart';
import 'screens/my_data_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final db = FirebaseFirestore.instance;

  await db.collection('test').add({
    'message': 'Connected!',
    'time': DateTime.now(),
  });
  
  await handleMonthlyUnlock();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monster Money',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        scaffoldBackgroundColor: const Color.fromARGB(255, 190, 233, 232),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const MyDataScreen(),
    const Center(
      child: Text('Page 3 (Scan Receipt)', style: TextStyle(fontSize: 22)),
    ),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScanReceiptScreen()),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: CustomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

Future<void> handleMonthlyUnlock() async {
  final db = FirebaseFirestore.instance;

  final unlocksRef = db.collection('user_unlocks').doc('unlocks');
  final snapshot = await unlocksRef.get();

  if (!snapshot.exists) return;

  final data = snapshot.data() as Map<String, dynamic>;

  final String? curMonthFromDb = data['cur_month'] as String?;

  final now = DateTime.now();

  String currentMonthKey =
      '${DateFormat('MMMM').format(now).toLowerCase()}_${now.year}';

  // currentMonthKey = 'december_2025'; // for testing

  if (curMonthFromDb == currentMonthKey) {
    return;
  }

  final DateTime prevMonthDate = DateTime(now.year, now.month - 1, 1);
  String previousMonthKey =
      '${DateFormat('MMMM').format(prevMonthDate).toLowerCase()}_${prevMonthDate.year}';

  // previousMonthKey = 'november_2025'; // for testing

  await nextMonthBudget(currentMonthKey, previousMonthKey);

  // Get outfits array
  final List<dynamic>? outfitsRaw = data['outfits'] as List<dynamic>?;
  if (outfitsRaw == null || outfitsRaw.isEmpty) {
    await unlocksRef.update({'cur_month': currentMonthKey});
    return;
  }

  // Find first locked outfit
  int? firstLockedIndex;
  for (int i = 0; i < outfitsRaw.length; i++) {
    final outfit = outfitsRaw[i] as Map<String, dynamic>;
    final unlocked = outfit['unlocked'] == true;
    if (!unlocked) {
      firstLockedIndex = i;
      break;
    }
  }

  if (firstLockedIndex == null) {
    // Everything already unlocked, just bump cur_month
    await unlocksRef.update({'cur_month': currentMonthKey});
    return;
  }

  final Map<String, dynamic> firstLockedOutfit =
      Map<String, dynamic>.from(outfitsRaw[firstLockedIndex] as Map);

  final String? category = firstLockedOutfit['unlock_method'] as String?;
  if (category == null) {
    await unlocksRef.update({'cur_month': currentMonthKey});
    return;
  }

  //Load previous month's budgets to see if user stayed within budget
  final budgetsDoc = await db
      .collection('budgets')
      .doc(previousMonthKey)
      .get();

  if (!budgetsDoc.exists) {
    await unlocksRef.update({'cur_month': currentMonthKey});
    return;
  }

  final budgetsData = budgetsDoc.data() as Map<String, dynamic>;

  final categoryData = budgetsData[category];
  if (categoryData is! Map<String, dynamic>) {
    await unlocksRef.update({'cur_month': currentMonthKey});
    return;
  }

  final double spent =
      (categoryData['spent'] as num? ?? 0).toDouble();
  final double budget =
      (categoryData['budget'] as num? ?? 0).toDouble();

  final bool withinBudget = spent <= budget;

  if (!withinBudget) {
    // User did not meet the goal for that category
    await unlocksRef.update({'cur_month': currentMonthKey});
    return;
  }

  // User stayed within budget
  firstLockedOutfit['unlocked'] = true;
  firstLockedOutfit['unlock_time'] = previousMonthKey; // e.g. "november_2025"
  outfitsRaw[firstLockedIndex] = firstLockedOutfit;

  await unlocksRef.update({
    'cur_month': currentMonthKey,
    'outfits': outfitsRaw,
  });
}

Future<void> nextMonthBudget(
    String curMonth,      
    String prevMonth,   
  ) async {
    final originalDocRef = FirebaseFirestore.instance
        .collection('budgets')
        .doc(prevMonth);

    final originalSnapshot = await originalDocRef.get();

    if (!originalSnapshot.exists) {
      return;
    }

    Map<String, dynamic> data =
        Map<String, dynamic>.from(originalSnapshot.data()!);

    data['name'] = curMonth;

    data.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        value['spent'] = 0;             
      }
    });

    final newDocRef = FirebaseFirestore.instance
        .collection('budgets')
        .doc(curMonth);

    await newDocRef.set(data);
  }