import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'addProduct.dart';
import 'filter.dart';
import 'statistics.dart';
import 'productInfo.dart';
import 'profile.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.android,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        primarySwatch: Colors.blue,
      ),
      home: ListPage(),
    );
  }
}

class ListPage extends StatefulWidget {
  const ListPage({super.key});

  @override
  State<ListPage> createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> with SingleTickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _allProducts = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _isSearchBarCollapsed = false;
  bool _isBottomBarCollapsed = false;
  double _lastScrollPosition = 0;
  String _searchQuery = '';
  Map<String, String> _activeFilters = {};
  bool _hasActiveFilters = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkLoginAndLoadProducts();
    
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scrollController.addListener(_handleScroll);
    _searchController.addListener(_handleSearch);
  }

  void _handleScroll() {
    if (_scrollController.position.pixels > 10 && !_isSearchBarCollapsed) {
      setState(() => _isSearchBarCollapsed = true);
      _animationController.forward();
    } else if (_scrollController.position.pixels <= 10 && _isSearchBarCollapsed) {
      setState(() => _isSearchBarCollapsed = false);
      _animationController.reverse();
    }

    if (_scrollController.position.pixels > _lastScrollPosition && !_isBottomBarCollapsed) {
      setState(() => _isBottomBarCollapsed = true);
    }
    _lastScrollPosition = _scrollController.position.pixels;
  }

  void _handleSearch() {
    setState(() {
      if (_searchQuery.isEmpty) {
        _products = _allProducts; // Show the entire list if the search query is empty
      } else {
        _products = _allProducts.where((product) {
          final name = (product['name'] ?? '').toString().toLowerCase();
          final category = (product['category'] ?? '').toString().toLowerCase();
          final price = (product['price'] ?? '').toString().toLowerCase();
          final purchaseDate = (product['purchaseDate'] ?? '').toString().toLowerCase();
          final warrantyPeriod = (product['warrantyPeriod'] ?? '').toString().toLowerCase();
          final storeDetails = (product['storeDetails'] ?? '').toString().toLowerCase();
          final brand = (product['brand'] ?? '').toString().toLowerCase();
          final notes = (product['notes'] ?? '').toString().toLowerCase();

          return name.contains(_searchQuery) ||
                 category.contains(_searchQuery) ||
                 price.contains(_searchQuery) ||
                 purchaseDate.contains(_searchQuery) ||
                 warrantyPeriod.contains(_searchQuery) ||
                 storeDetails.contains(_searchQuery) ||
                 brand.contains(_searchQuery) ||
                 notes.contains(_searchQuery);
        }).toList();
      }
    });
  }

  Future<void> _addProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddProductPage()),
    );

    if (result == true) {
      // Product was added successfully, refresh the list
      setState(() {
        _isBottomBarCollapsed = false;
        _isLoading = true; // Show loading indicator while refreshing
      });
      
      // Reload products from Firestore
      await _loadProducts();
    }
  }

  // Helper method to parse warranty period to months
  int _parseWarrantyToMonths(String warrantyPeriod) {
    if (warrantyPeriod.isEmpty) return 0;
    if (warrantyPeriod.toLowerCase() == 'lifetime') return -1; // Special case for lifetime

    final parts = warrantyPeriod.toLowerCase().split(' ');
    if (parts.length != 2) return 0;

    final value = int.tryParse(parts[0]) ?? 0;
    final unit = parts[1];

    switch (unit) {
      case 'days':
        return (value / 30).ceil(); // Convert days to months
      case 'months':
        return value;
      case 'years':
        return value * 12;
      default:
        return 0;
    }
  }

  // Helper method to parse price string to double
  double _parsePrice(String price) {
    if (price.isEmpty) return 0.0;
    // Remove all non-numeric characters except decimal point
    final numericString = price.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(numericString) ?? 0.0;
  }

  Future<void> _loadProducts() async {
    if (_auth.currentUser == null) {
      setState(() {
        _errorMessage = 'Please sign in to view your products';
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid);
      final productsCollection = userDoc.collection('products');
      
      final snapshot = await productsCollection.get();
      List<Map<String, dynamic>> allProducts = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

      // Apply filters if any
      if (_activeFilters.isNotEmpty) {
        allProducts = allProducts.where((product) {
          // Product name filter (contains match, case insensitive)
          if (_activeFilters['name']?.isNotEmpty ?? false) {
            final name = (product['name'] ?? '').toString().toLowerCase();
            if (!name.contains(_activeFilters['name']!.toLowerCase())) {
              return false;
            }
          }
          
          // Price range filter with improved parsing
          if (_activeFilters['minPrice']?.isNotEmpty ?? false) {
            final price = _parsePrice(product['price']?.toString() ?? '0');
            final minPrice = _parsePrice(_activeFilters['minPrice']!);
            if (price < minPrice) {
              return false;
            }
          }
          if (_activeFilters['maxPrice']?.isNotEmpty ?? false) {
            final price = _parsePrice(product['price']?.toString() ?? '0');
            final maxPrice = _parsePrice(_activeFilters['maxPrice']!);
            if (price > maxPrice) {
              return false;
            }
          }
          
          // Date range filter with null safety
          if (_activeFilters['startDate']?.isNotEmpty ?? false) {
            final purchaseDate = DateTime.tryParse(product['purchaseDate'] ?? '');
            final startDate = DateTime.tryParse(_activeFilters['startDate']!);
            if (purchaseDate == null || startDate == null || purchaseDate.isBefore(startDate)) {
              return false;
            }
          }
          if (_activeFilters['endDate']?.isNotEmpty ?? false) {
            final purchaseDate = DateTime.tryParse(product['purchaseDate'] ?? '');
            final endDate = DateTime.tryParse(_activeFilters['endDate']!);
            if (purchaseDate == null || endDate == null || purchaseDate.isAfter(endDate)) {
              return false;
            }
          }
          
          // Warranty period range filter with improved handling
          if (_activeFilters['minWarrantyPeriod']?.isNotEmpty ?? false) {
            final warrantyMonths = _parseWarrantyToMonths(product['warrantyPeriod'] ?? '0');
            final minWarrantyMonths = _parseWarrantyToMonths(_activeFilters['minWarrantyPeriod']!);
            
            // Handle lifetime warranty
            if (warrantyMonths == -1) return true; // Lifetime warranty passes all filters
            if (minWarrantyMonths == -1) return false; // Can't meet lifetime minimum
            if (warrantyMonths < minWarrantyMonths) {
              return false;
            }
          }
          if (_activeFilters['maxWarrantyPeriod']?.isNotEmpty ?? false) {
            final warrantyMonths = _parseWarrantyToMonths(product['warrantyPeriod'] ?? '0');
            final maxWarrantyMonths = _parseWarrantyToMonths(_activeFilters['maxWarrantyPeriod']!);
            
            // Handle lifetime warranty
            if (warrantyMonths == -1) {
              return maxWarrantyMonths == -1; // Only pass if max is also lifetime
            }
            if (maxWarrantyMonths == -1) return true; // All warranties are less than lifetime
            if (warrantyMonths > maxWarrantyMonths) {
              return false;
            }
          }
          
          // Warranty extension range filter with improved handling
          if (_activeFilters['minWarrantyExtension']?.isNotEmpty ?? false) {
            final extensionMonths = _parseWarrantyToMonths(product['warrantyExtension'] ?? '0');
            final minExtensionMonths = _parseWarrantyToMonths(_activeFilters['minWarrantyExtension']!);
            
            if (extensionMonths == -1) return true; // Lifetime extension passes all filters
            if (minExtensionMonths == -1) return false; // Can't meet lifetime minimum
            if (extensionMonths < minExtensionMonths) {
              return false;
            }
          }
          if (_activeFilters['maxWarrantyExtension']?.isNotEmpty ?? false) {
            final extensionMonths = _parseWarrantyToMonths(product['warrantyExtension'] ?? '0');
            final maxExtensionMonths = _parseWarrantyToMonths(_activeFilters['maxWarrantyExtension']!);
            
            if (extensionMonths == -1) {
              return maxExtensionMonths == -1; // Only pass if max is also lifetime
            }
            if (maxExtensionMonths == -1) return true; // All extensions are less than lifetime
            if (extensionMonths > maxExtensionMonths) {
              return false;
            }
          }
          
          // Multiple selection filters with null safety
          if (_activeFilters['categories']?.isNotEmpty ?? false) {
            final selectedCategories = _activeFilters['categories']!.split(',');
            final category = (product['category'] ?? '').toString();
            if (!selectedCategories.contains(category)) {
              return false;
            }
          }
          
          if (_activeFilters['brands']?.isNotEmpty ?? false) {
            final selectedBrands = _activeFilters['brands']!.split(',');
            final brand = (product['brand'] ?? '').toString();
            if (!selectedBrands.contains(brand)) {
              return false;
            }
          }
          
          if (_activeFilters['stores']?.isNotEmpty ?? false) {
            final selectedStores = _activeFilters['stores']!.split(',');
            final store = (product['storeDetails'] ?? '').toString();
            if (!selectedStores.contains(store)) {
              return false;
            }
          }
          
          return true;
        }).toList();
      }

      // Apply search query with improved matching
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        allProducts = allProducts.where((product) {
          final searchableFields = [
            product['name']?.toString() ?? '',
            product['category']?.toString() ?? '',
            product['price']?.toString() ?? '',
            product['purchaseDate']?.toString() ?? '',
            product['warrantyPeriod']?.toString() ?? '',
            product['warrantyExtension']?.toString() ?? '',
            product['storeDetails']?.toString() ?? '',
            product['brand']?.toString() ?? '',
            product['notes']?.toString() ?? '',
          ];
          
          return searchableFields.any((field) => 
            field.toLowerCase().contains(query));
        }).toList();
      }

      // Apply sorting with improved comparisons
      if (_activeFilters.containsKey('sortField') && _activeFilters['sortField']!.isNotEmpty) {
        final sortField = _activeFilters['sortField']!;
        final isAscending = (_activeFilters['sortDirection'] ?? 'asc') == 'asc';
        
        allProducts.sort((a, b) {
          var valueA = a[sortField];
          var valueB = b[sortField];
          
          // Handle null values
          if (valueA == null && valueB == null) return 0;
          if (valueA == null) return isAscending ? -1 : 1;
          if (valueB == null) return isAscending ? 1 : -1;
          
          // Special handling for different field types
          switch (sortField) {
            case 'price':
              final priceA = _parsePrice(valueA.toString());
              final priceB = _parsePrice(valueB.toString());
              return isAscending ? priceA.compareTo(priceB) : priceB.compareTo(priceA);
              
            case 'purchaseDate':
              final dateA = DateTime.tryParse(valueA.toString()) ?? DateTime(1900);
              final dateB = DateTime.tryParse(valueB.toString()) ?? DateTime(1900);
              return isAscending ? dateA.compareTo(dateB) : dateB.compareTo(dateA);
              
            case 'warrantyPeriod':
            case 'warrantyExtension':
              final monthsA = _parseWarrantyToMonths(valueA.toString());
              final monthsB = _parseWarrantyToMonths(valueB.toString());
              // Handle lifetime warranty in sorting
              if (monthsA == -1 && monthsB == -1) return 0;
              if (monthsA == -1) return isAscending ? 1 : -1;
              if (monthsB == -1) return isAscending ? -1 : 1;
              return isAscending ? monthsA.compareTo(monthsB) : monthsB.compareTo(monthsA);
              
            default:
              // Default string comparison
              return isAscending ? 
                valueA.toString().compareTo(valueB.toString()) :
                valueB.toString().compareTo(valueA.toString());
          }
        });
      }

      setState(() {
        _products = allProducts;
        _allProducts = allProducts;
        _isLoading = false;
      });
      
      // Check for warranty expiry dates and schedule notifications
      _checkWarrantyExpiryDates(allProducts);

    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to load your products. Please check your connection and try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _checkWarrantyExpiryDates(List<Map<String, dynamic>> products) async {
    // Initialize the notification service
    final notificationService = NotificationService();
    
    // Check each product for warranty expiry
    for (var product in products) {
      final String? purchaseDate = product['purchaseDate'];
      final String? warrantyPeriod = product['warrantyPeriod'];
      final String? warrantyExtension = product['warrantyExtension'];
      
      if (purchaseDate != null && warrantyPeriod != null) {
        // Calculate expiry date using the notification service
        final expiryDate = notificationService.calculateExpiryDate(
          purchaseDate, 
          warrantyPeriod, 
          warrantyExtension
        );
        
        if (expiryDate != null) {
          // Add expiry date to the product data for display
          product['expiryDate'] = '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';
          
          // Calculate days until expiry
          final now = DateTime.now();
          final daysUntilExpiry = expiryDate.difference(now).inDays;
          
          // Add days until expiry to the product data for display
          product['daysUntilExpiry'] = daysUntilExpiry;
        }
      }
    }
  }

  void _handleFilters(Map<String, String> filters) {
    setState(() {
      _activeFilters = filters;
      _hasActiveFilters = filters.values.any((value) => value.isNotEmpty);
      _currentIndex = 0; // Return to list view
    });
    
    // Reload products with new filters
    _loadProducts();
  }

  Future<void> _checkLoginAndLoadProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

      if (!isLoggedIn) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginScreen()),
          );
        }
        return;
      }

      await _loadProducts();
    } catch (e) {
      setState(() {
        _errorMessage = 'Unable to initialize the app. Please restart and try again.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _calculateExpiryDate(String? purchaseDate, String? warrantyPeriod, String? warrantyExtension) {
    if (purchaseDate == null || warrantyPeriod == null) return 'Unknown';
    if (warrantyPeriod.toLowerCase() == 'lifetime') return 'Never expires';
    try {
      final purchaseDateTime = DateTime.parse(purchaseDate);
      final warrantyDays = _parseWarrantyPeriod(warrantyPeriod);
      final extensionDays = _parseWarrantyPeriod(warrantyExtension ?? '0');
      final expiryDate = purchaseDateTime.add(Duration(days: warrantyDays + extensionDays));
      return '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  int _parseWarrantyPeriod(String warranty) {
    if (warranty.isEmpty) return 0;
    if (warranty.toLowerCase() == 'lifetime') return 36500; // 100 years as lifetime
    
    // Split value and unit
    final parts = warranty.toLowerCase().split(' ');
    if (parts.length < 2) return 0;
    
    final value = int.tryParse(parts[0]) ?? 0;
    final unit = parts[1];
    
    if (unit.startsWith('day')) {
      return value;
    } else if (unit.startsWith('month')) {
      return value * 30;
    } else if (unit.startsWith('year')) {
      return value * 365;
    }
    return 0;
  }
  
  bool _isWarrantyExpiringSoon(Map<String, dynamic> product) {
    try {
      final String? warrantyPeriod = product['warrantyPeriod'];
      if (warrantyPeriod?.toLowerCase() == 'lifetime') return false;
      
      final String? purchaseDate = product['purchaseDate'];
      final String? warrantyExtension = product['warrantyExtension'];
      
      if (purchaseDate == null || warrantyPeriod == null) return false;
      
      final purchaseDateTime = DateTime.parse(purchaseDate);
      final warrantyDays = _parseWarrantyPeriod(warrantyPeriod);
      final extensionDays = _parseWarrantyPeriod(warrantyExtension ?? '0');
      final expiryDate = purchaseDateTime.add(Duration(days: warrantyDays + extensionDays));
      
      final now = DateTime.now();
      final daysUntilExpiry = expiryDate.difference(now).inDays;
      
      return daysUntilExpiry <= 30;
    } catch (e) {
      return false;
    }
  }
  
  Color _getExpiryTextColor(Map<String, dynamic> product) {
    try {
      final String? warrantyPeriod = product['warrantyPeriod'];
      if (warrantyPeriod?.toLowerCase() == 'lifetime') return Colors.green;
      
      final String? purchaseDate = product['purchaseDate'];
      final String? warrantyExtension = product['warrantyExtension'];
      
      if (purchaseDate == null || warrantyPeriod == null) return Colors.black;
      
      final purchaseDateTime = DateTime.parse(purchaseDate);
      final warrantyDays = _parseWarrantyPeriod(warrantyPeriod);
      final extensionDays = _parseWarrantyPeriod(warrantyExtension ?? '0');
      final expiryDate = purchaseDateTime.add(Duration(days: warrantyDays + extensionDays));
      
      final now = DateTime.now();
      final daysUntilExpiry = expiryDate.difference(now).inDays;
      
      if (daysUntilExpiry < 0) {
        return Colors.red;
      } else if (daysUntilExpiry <= 1) {
        return Colors.red;
      } else if (daysUntilExpiry <= 7) {
        return Colors.orange;
      } else if (daysUntilExpiry <= 30) {
        return Colors.amber[700]!;
      }
      
      return Colors.black;
    } catch (e) {
      return Colors.black;
    }
  }
  
  Color _getExpiryBadgeColor(Map<String, dynamic> product) {
    try {
      final String? purchaseDate = product['purchaseDate'];
      final String? warrantyPeriod = product['warrantyPeriod'];
      final String? warrantyExtension = product['warrantyExtension'];
      
      if (purchaseDate == null || warrantyPeriod == null) return Colors.grey;
      
      final purchaseDateTime = DateTime.parse(purchaseDate);
      final warrantyDays = _parseWarrantyPeriod(warrantyPeriod);
      final extensionDays = _parseWarrantyPeriod(warrantyExtension ?? '0');
      final expiryDate = purchaseDateTime.add(Duration(days: warrantyDays + extensionDays));
      
      final now = DateTime.now();
      final daysUntilExpiry = expiryDate.difference(now).inDays;
      
      if (daysUntilExpiry < 0) {
        return Colors.red[700]!; // Already expired
      } else if (daysUntilExpiry <= 1) {
        return Colors.red; // Expires today or tomorrow
      } else if (daysUntilExpiry <= 7) {
        return Colors.orange; // Expires within a week
      } else if (daysUntilExpiry <= 30) {
        return Colors.amber[700]!; // Expires within a month
      }
      
      return Colors.green; // Not expiring soon
    } catch (e) {
      return Colors.grey;
    }
  }
  
  String _getExpiryBadgeText(Map<String, dynamic> product) {
    try {
      final String? warrantyPeriod = product['warrantyPeriod'];
      if (warrantyPeriod?.toLowerCase() == 'lifetime') return '';
      
      final String? purchaseDate = product['purchaseDate'];
      final String? warrantyExtension = product['warrantyExtension'];
      
      if (purchaseDate == null || warrantyPeriod == null) return '';
      
      final purchaseDateTime = DateTime.parse(purchaseDate);
      final warrantyDays = _parseWarrantyPeriod(warrantyPeriod);
      final extensionDays = _parseWarrantyPeriod(warrantyExtension ?? '0');
      final expiryDate = purchaseDateTime.add(Duration(days: warrantyDays + extensionDays));
      
      final now = DateTime.now();
      final daysUntilExpiry = expiryDate.difference(now).inDays;
      
      if (daysUntilExpiry < 0) {
        return 'EXPIRED';
      } else if (daysUntilExpiry == 0) {
        return 'EXPIRES TODAY';
      } else if (daysUntilExpiry == 1) {
        return 'EXPIRES TOMORROW';
      } else if (daysUntilExpiry <= 7) {
        return '$daysUntilExpiry DAYS LEFT';
      } else if (daysUntilExpiry <= 30) {
        return '$daysUntilExpiry DAYS LEFT';
      }
      
      return '';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAFE1F0),
      body: SafeArea(
        child: _buildCurrentView(),
      ),
      bottomNavigationBar: GestureDetector(
        onTap: _isBottomBarCollapsed ? () => setState(() => _isBottomBarCollapsed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _isBottomBarCollapsed ? 15 : 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: _isBottomBarCollapsed
              ? Container()
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    IconButton(
                      icon: Icon(Icons.home_outlined,
                        color: _currentIndex == 0 ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => setState(() => _currentIndex = 0),
                    ),
                    IconButton(
                      icon: Icon(Icons.bar_chart,
                        color: _currentIndex == 1 ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => setState(() => _currentIndex = 1),
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: FloatingActionButton(
                        backgroundColor: Colors.blue,
                        child: const Icon(Icons.add, size: 30),
                        onPressed: _addProduct,
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: Icon(Icons.filter_list,
                            color: _currentIndex == 2 ? Colors.blue : Colors.grey,
                          ),
                          onPressed: () => setState(() => _currentIndex = 2),
                        ),
                        if (_hasActiveFilters)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.person_outline,
                        color: _currentIndex == 3 ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => setState(() => _currentIndex = 3),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildCurrentView() {
    if (_currentIndex == 1) {
      return StatisticsPage();
    } else if (_currentIndex == 2) {
      return FilterPage(
        onApplyFilters: (filters) {
          _handleFilters(filters);
          setState(() => _currentIndex = 0); // Return to list view after applying filters
        },
        activeFilters: _activeFilters,
      );
    } else if (_currentIndex == 3) {
      return ProfilePage();
    }
    // Return the main list view for other tabs
    return Stack(
      children: [
        Column(
          children: [
            SizedBox(height: _isSearchBarCollapsed ? 80 : 88),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadProducts,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _products.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 30.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 80,
                                      color: Colors.blue.withOpacity(0.7),
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      'Your product list is empty',
                                      style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "Add products to MyWarranties to keep track of your warranties and never miss an expiration date again.",
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 16,
                                        height: 1.4,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 30),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => AddProductPage()),
                                        ).then((result) {
                                          if (result == true) {
                                            setState(() {
                                              _isLoading = true;
                                            });
                                            _loadProducts();
                                          }
                                        });
                                      },
                                      icon: Icon(Icons.add),
                                      label: Text('Add Your First Product'),
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        textStyle: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              itemCount: _products.length,
                              itemBuilder: (context, index) {
                                final product = _products[index];
                                return GestureDetector(
                                  onTap: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProductInfoPage(product: product),
                                      ),
                                    );
                                    
                                    // If the product was updated or deleted, refresh the list
                                    if (result == true) {
                                      setState(() {
                                        _isLoading = true;
                                      });
                                      await _loadProducts();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 8.0,
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          children: [
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                product['imageUrl'] ?? '',
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    width: 120,
                                                    height: 120,
                                                    color: Colors.grey[300],
                                                    child: const Icon(Icons.image_not_supported),
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    product['name'] ?? 'Unknown Product',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 24,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    'Warranty: ${product['warrantyPeriod'] ?? 'Unknown'}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Text(
                                                    'Warranty Extension: ${product['warrantyExtension'] ?? 'None'}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Expires: ${_calculateExpiryDate(product['purchaseDate'], product['warrantyPeriod'], product['warrantyExtension'])}',
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 16,
                                                            color: _getExpiryTextColor(product),
                                                            fontWeight: _isWarrantyExpiringSoon(product) ? FontWeight.bold : FontWeight.normal,
                                                          ),
                                                        ),
                                                      ),
                                                      if (_isWarrantyExpiringSoon(product))
                                                        Container(
                                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: _getExpiryBadgeColor(product),
                                                            borderRadius: BorderRadius.circular(12),
                                                          ),
                                                          child: Text(
                                                            _getExpiryBadgeText(product),
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 12,
                                                            ),
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
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 200),
          top: 16,
          left: 16,
          right: 16,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _isSearchBarCollapsed ? 50 : 56,
            width: _isSearchBarCollapsed 
                ? 56 
                : MediaQuery.of(context).size.width - 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_isSearchBarCollapsed ? 15 : 30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _isSearchBarCollapsed
                ? IconButton(
                    icon: const Icon(Icons.search, color: Colors.grey),
                    onPressed: () {
                      setState(() => _isSearchBarCollapsed = false);
                      _animationController.reverse();
                      _scrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  )
                : TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                      _handleSearch();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
