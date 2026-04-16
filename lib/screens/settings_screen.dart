import 'package:flutter/material.dart';
import 'package:monster_money_manager/screens/budget_screen.dart';
import 'package:monster_money_manager/screens/profile_screen.dart';
import 'package:monster_money_manager/screens/receipts_screen.dart';
import '../components/navbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  
  bool _notificationsOn = true;
  
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
                  const Icon(Icons.settings_outlined, size: 26),
                  const SizedBox(width: 8),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Roboto',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),
            
            userInfo(),

            const SizedBox(height: 40),

            // List Options
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildOption(context, 'Edit Profile'),
                    _buildOption(context, 'Manage Budget Preferences'),
                  ],
                ),
              ),
            ),

          ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: 0.6,
              child: Image.asset('assets/webp/sleep.webp', fit: BoxFit.cover,)),
            )
          ],
        ),
      ),
    );
  }

  Widget _switchOption(BuildContext context, String title, bool isOn, ValueChanged<bool> onChanged) {
    return InkWell(
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
            Switch(
              value: isOn,
              onChanged: onChanged,
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
              fontSize: 16,
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
                  size: 44,
                  color: Colors.black87,
                ),
                const SizedBox(width: 13),
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
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

  Widget _buildOption(BuildContext context, String title) {
    return InkWell(
      onTap: () {
        if (title == 'Manage Budget Preferences') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BudgetScreen()),
          );
        } else if (title == 'Edit Profile') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfileScreen()),
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
