import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({Key? key}) : super(key: key);

  @override
  _StatisticsPageState createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  int endingSoon = 0;
  int addedRecently = 0;
  double totalValue = 0;
  int productCount = 0;
  int expiredCount = 0;
  int warrantyOverYear = 0;
  double mostExpensive = 0;
  double averageValue = 0;
  int addedThisYear = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStatistics();
  }

  Future<void> _fetchStatistics() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final productsRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('products');
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final thirtyDaysFromNow = now.add(const Duration(days: 30));
    final startOfYear = DateTime(now.year, 1, 1);

    final snapshot = await productsRef.get();
    int ending = 0;
    int added = 0;
    double value = 0;
    int count = snapshot.docs.length;
    int expired = 0;
    int warrantyYear = 0;
    double mostExp = 0;
    int addedYear = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      // Ending within 30 days
      if (data['expiryDate'] != null) {
        try {
          final expiry = DateTime.parse(data['expiryDate']);
          if (expiry.isAfter(now) && expiry.isBefore(thirtyDaysFromNow)) {
            ending++;
          }
          // Expired products
          if (expiry.isBefore(now)) {
            expired++;
          }
        } catch (_) {}
      }
      // Added in last 30 days & this year
      if (data['createdAt'] != null) {
        try {
          DateTime created;
          if (data['createdAt'] is Timestamp) {
            created = (data['createdAt'] as Timestamp).toDate();
          } else if (data['createdAt'] is String) {
            created = DateTime.parse(data['createdAt']);
          } else {
            created = DateTime.now().subtract(const Duration(days: 3650)); // fallback
          }
          if (created.isAfter(thirtyDaysAgo)) {
            added++;
          }
          if (created.isAfter(startOfYear)) {
            addedYear++;
          }
        } catch (_) {}
      }
      // Total value, most expensive, average
      if (data['price'] != null) {
        try {
          final price = double.tryParse(data['price'].toString()) ?? 0;
          value += price;
          if (price > mostExp) mostExp = price;
        } catch (_) {}
      }
      // Warranty > 1 year
      if (data['warrantyPeriod'] != null) {
        try {
          final warrantyString = data['warrantyPeriod'].toString().toLowerCase();
          int periodInMonths = 0;

          if (warrantyString.contains('month')) {
            periodInMonths = int.tryParse(warrantyString.split(' ')[0]) ?? 0;
          } else if (warrantyString.contains('year')) {
            periodInMonths = (int.tryParse(warrantyString.split(' ')[0]) ?? 0) * 12;
          }

          if (periodInMonths > 12) {
            warrantyYear++;
          }
        } catch (_) {}
      }
    }
    double avg = count > 0 ? value / count : 0;
    setState(() {
      endingSoon = ending;
      addedRecently = added;
      totalValue = value;
      productCount = count;
      expiredCount = expired;
      warrantyOverYear = warrantyYear;
      mostExpensive = mostExp;
      averageValue = avg;
      addedThisYear = addedYear;
      isLoading = false;
    });
  }

  Widget _statCard(String value, String label, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black54, width: 1),
      ),
      width: 160,
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 32,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAFE1F0),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statCard('$endingSoon', 'Ending within 30 days', Colors.purple),
                          _statCard('$addedRecently', 'Added in the last 30 days', Colors.green),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statCard('${totalValue.toStringAsFixed(0)}€', 'Total Value', Colors.amber[700] ?? Colors.amber),
                          _statCard('$productCount', 'Number of products', Colors.teal),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statCard('$expiredCount', 'Expired Products', Colors.red),
                          _statCard('$warrantyOverYear', 'Warranty > 1 Year', Colors.deepPurple),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statCard('${mostExpensive.toStringAsFixed(0)}€', 'Most Expensive', Colors.orange),
                          _statCard('${averageValue.toStringAsFixed(0)}€', 'Average Value', Colors.blueGrey),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _statCard('$addedThisYear', 'Added This Year', Colors.indigo),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
