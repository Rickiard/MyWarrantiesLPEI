import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/notification_service.dart';

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

  // Helper function to calculate expiry date
  DateTime? _calculateExpiryDate(String? purchaseDate, String? warrantyPeriod, String? warrantyUnit, String? warrantyExtension) {
    print('Calculating expiry date for purchase: $purchaseDate, warranty: $warrantyPeriod, unit: $warrantyUnit, extension: $warrantyExtension');
    
    if (purchaseDate == null || warrantyPeriod == null) {
      print('Missing purchase date or warranty period');
      return null;
    }
    
    if (warrantyPeriod.toLowerCase().trim() == 'lifetime' || 
        (warrantyUnit != null && warrantyUnit.toLowerCase().trim() == 'lifetime')) {
      print('Lifetime warranty, no expiry date');
      return null; // Lifetime warranty never expires
    }
    
    try {
      String formattedWarranty = warrantyPeriod;
      
      // If warrantyPeriod is just a number and warrantyUnit is separate, combine them
      if (!warrantyPeriod.contains(' ') && warrantyUnit != null) {
        formattedWarranty = '$warrantyPeriod $warrantyUnit';
      }
      
      // Use the notification service for consistent date calculation
      final notificationService = NotificationService();
      final expiryDate = notificationService.calculateExpiryDate(
        purchaseDate, 
        formattedWarranty, 
        warrantyExtension
      );
      
      print('Calculated expiry date: $expiryDate');
      return expiryDate;
    } catch (e) {
      print('Error calculating expiry date: $e');
      return null;
    }
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
    
    // Debug: Print total number of products
    print('Total products: ${snapshot.docs.length}');
    
    // Lists to store debug info
    List<String> productsWithLongWarranty = [];
    List<String> warrantyPeriods = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final String productName = data['name'] ?? 'Unknown Product';
      
      // Calculate expiry date
      final String? purchaseDate = data['purchaseDate'];
      final String? warrantyPeriod = data['warrantyPeriod'];
      final String? warrantyUnit = data['warrantyUnit'];
      final String? warrantyExtension = data['warrantyExtension'];
      
      // Debug: Print all warranty periods
      if (warrantyPeriod != null) {
        warrantyPeriods.add('$productName: $warrantyPeriod');
      }
      
      // Check for products ending soon or expired
      if (purchaseDate != null && warrantyPeriod != null) {
        // Skip lifetime warranties for expiry calculations
        if (warrantyPeriod.toLowerCase().trim() != 'lifetime' && 
            (warrantyUnit == null || warrantyUnit.toLowerCase().trim() != 'lifetime')) {
          final expiryDate = _calculateExpiryDate(purchaseDate, warrantyPeriod, warrantyUnit, warrantyExtension);
          
          if (expiryDate != null) {
            // Ending within 30 days
            if (expiryDate.isAfter(now) && expiryDate.isBefore(thirtyDaysFromNow)) {
              ending++;
            }
            // Expired products
            if (expiryDate.isBefore(now)) {
              expired++;
            }
          }
        }
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
      if (warrantyPeriod != null) {
        try {
          // Check if it's a lifetime warranty
          if (warrantyPeriod.toLowerCase().trim() == 'lifetime' || 
              (warrantyUnit != null && warrantyUnit.toLowerCase().trim() == 'lifetime')) {
            warrantyYear++;
            productsWithLongWarranty.add('$productName: Lifetime warranty');
            print('Found lifetime warranty product: $productName');
          } else {
            // For non-lifetime warranties, use the notification service to calculate
            String formattedWarranty = warrantyPeriod;
            
            // If warrantyPeriod is just a number and warrantyUnit is separate, combine them
            if (!warrantyPeriod.contains(' ') && warrantyUnit != null) {
              formattedWarranty = '$warrantyPeriod $warrantyUnit';
            }
            
            // Use the notification service for consistent calculation
            NotificationService notificationService = NotificationService();
            int warrantyDays = notificationService.parseWarrantyPeriodToDays(formattedWarranty);

            if (warrantyDays > 365) { // More than 1 year
              warrantyYear++;
              productsWithLongWarranty.add('$productName: $warrantyPeriod $warrantyUnit (${warrantyDays} days)');
              print('Found >1 year warranty product: $productName, Period: $warrantyPeriod, Unit: $warrantyUnit, Days: $warrantyDays');
            }
          }
        } catch (e) {
          print('Error processing warranty for $productName: $e');
        }
      }
    }
    
    // Debug: Print all warranty periods and products with long warranties
    print('All warranty periods: $warrantyPeriods');
    print('Products with >1 year warranty: $productsWithLongWarranty');
    print('Total products with >1 year warranty: $warrantyYear');
    
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


