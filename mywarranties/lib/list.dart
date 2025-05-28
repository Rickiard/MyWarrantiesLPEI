import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:io';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'addProduct.dart';
import 'filter.dart';
import 'statistics.dart';
import 'productInfo.dart';
import 'profile.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';

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
  String _searchQuery = '';  Map<String, String> _activeFilters = {};
  bool _hasActiveFilters = false;
  int _currentIndex = 0;
  
  // Connectivity
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isConnected = true;
  bool _showingNoInternetDialog = false;  @override
  void initState() {
    super.initState();
    _checkLoginAndLoadProducts();
    
    _scrollController = ScrollController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scrollController.addListener(_handleScroll);
    
    // Initialize connectivity monitoring with a delay to avoid conflicts during navigation
    _initializeConnectivityWithDelay();
    
    // Verificar notificações diárias quando a app é aberta
    _checkDailyNotifications();
  }

  // Initialize connectivity monitoring with a delay to prevent conflicts during navigation
  void _initializeConnectivityWithDelay() async {
    // Espera a navegação estabilizar antes de monitorar conectividade
    await Future.delayed(Duration(milliseconds: 1200));
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      _initializeConnectivity();
    }
  }

  // Novo método para verificar notificações diárias
  void _checkDailyNotifications() async {
    try {
      // Aguardar um pouco para a app estabilizar
      await Future.delayed(Duration(seconds: 2));
      
      final notificationService = NotificationService();
      
      // Verificar e executar notificações se necessário
      await notificationService.checkAndExecuteDailyNotifications();
      
      // Log do status para debug
      final status = await notificationService.getDailyNotificationStatus();
      print('📊 Status das notificações diárias: $status');
      
    } catch (e) {
      print('❌ Erro ao verificar notificações diárias: $e');
    }
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
    } else if (_scrollController.position.pixels <= 10 && _isBottomBarCollapsed) {
      setState(() => _isBottomBarCollapsed = false);
    }
    _lastScrollPosition = _scrollController.position.pixels;
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
  double _parseWarrantyToMonths(String warrantyPeriod) {
    if (warrantyPeriod.isEmpty) return 0;
    
    // Handle lifetime warranty - more robust check
    if (warrantyPeriod.toLowerCase().contains('lifetime')) {
      return -1; // Use -1 to represent lifetime
    }
    
    final parts = warrantyPeriod.toLowerCase().trim().split(' ');
    if (parts.length < 2) return 0;
    
    try {
      final value = double.parse(parts[0]);
      final unit = parts[1];
      
      switch (unit) {
        case 'day':
        case 'days':
          return value / 30; // Approximate days to months
        case 'month':
        case 'months':
          return value;
        case 'year':
        case 'years':
          return value * 12;
        default:
          return 0;
      }
    } catch (e) {
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
    // Check internet connection first
    if (!await ConnectivityService().hasInternetConnection()) {
      setState(() {
        _errorMessage = 'No internet connection. Please check your network and try again.';
        _isLoading = false;
      });
      return;
    }

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
      _allProducts = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();

      // Apply filters if any
      if (_activeFilters.isNotEmpty) {
        _allProducts = _allProducts.where((product) {
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
            // Expiry date range filter with null safety
          if (_activeFilters['startExpiryDate']?.isNotEmpty ?? false) {
            final expiryDate = _calculateExpiryDateForFiltering(product);
            final startExpiryDate = DateTime.tryParse(_activeFilters['startExpiryDate']!);
            if (expiryDate == null || startExpiryDate == null || expiryDate.isBefore(startExpiryDate)) {
              return false;
            }
          }
          if (_activeFilters['endExpiryDate']?.isNotEmpty ?? false) {
            final expiryDate = _calculateExpiryDateForFiltering(product);
            final endExpiryDate = DateTime.tryParse(_activeFilters['endExpiryDate']!);
            if (expiryDate == null || endExpiryDate == null || expiryDate.isAfter(endExpiryDate)) {
              return false;
            }
          }
          
          // Warranty period range filter with improved handling for lifetime warranties
          if (_activeFilters['minWarrantyPeriod']?.isNotEmpty ?? false) {
            final warrantyPeriod = product['warrantyPeriod'] ?? '0';
            final minWarrantyPeriod = _activeFilters['minWarrantyPeriod']!;
            
            // Special handling for lifetime warranty in product
            if (warrantyPeriod.toLowerCase().contains('lifetime')) {
              // Lifetime warranty passes all minimum filters
              return true;
            }
            
            // Special handling for lifetime in filter criteria
            if (minWarrantyPeriod.toLowerCase().contains('lifetime')) {
              // If filter requires lifetime but product doesn't have it, fail
              return false;
            }
            
            // Normal numeric comparison
            final warrantyMonths = _parseWarrantyToMonths(warrantyPeriod);
            final minWarrantyMonths = _parseWarrantyToMonths(minWarrantyPeriod);
            
            if (warrantyMonths < minWarrantyMonths) {
              return false;
            }
          }
          
          if (_activeFilters['maxWarrantyPeriod']?.isNotEmpty ?? false) {
            final warrantyPeriod = product['warrantyPeriod'] ?? '0';
            final maxWarrantyPeriod = _activeFilters['maxWarrantyPeriod']!;
            
            // Special handling for lifetime warranty in product
            if (warrantyPeriod.toLowerCase().contains('lifetime')) {
              // If max filter is also lifetime, pass; otherwise fail
              return maxWarrantyPeriod.toLowerCase().contains('lifetime');
            }
            
            // If max filter is lifetime, all non-lifetime warranties pass
            if (maxWarrantyPeriod.toLowerCase().contains('lifetime')) {
              return true;
            }
            
            // Normal numeric comparison
            final warrantyMonths = _parseWarrantyToMonths(warrantyPeriod);
            final maxWarrantyMonths = _parseWarrantyToMonths(maxWarrantyPeriod);
            
            if (warrantyMonths > maxWarrantyMonths) {
              return false;
            }
          }
          
          // Warranty extension range filter with improved handling for lifetime warranties
          if (_activeFilters['minWarrantyExtension']?.isNotEmpty ?? false) {
            final warrantyExtension = product['warrantyExtension'] ?? '0';
            final minWarrantyExtension = _activeFilters['minWarrantyExtension']!;
            
            // Special handling for lifetime warranty extension in product
            if (warrantyExtension.toLowerCase().contains('lifetime')) {
              // Lifetime extension passes all minimum filters
              return true;
            }
            
            // Special handling for lifetime in filter criteria
            if (minWarrantyExtension.toLowerCase().contains('lifetime')) {
              // If filter requires lifetime but product doesn't have it, fail
              return false;
            }
            
            // Normal numeric comparison
            final extensionMonths = _parseWarrantyToMonths(warrantyExtension);
            final minExtensionMonths = _parseWarrantyToMonths(minWarrantyExtension);
            
            if (extensionMonths < minExtensionMonths) {
              return false;
            }
          }
          
          if (_activeFilters['maxWarrantyExtension']?.isNotEmpty ?? false) {
            final warrantyExtension = product['warrantyExtension'] ?? '0';
            final maxWarrantyExtension = _activeFilters['maxWarrantyExtension']!;
            
            // Special handling for lifetime warranty extension in product
            if (warrantyExtension.toLowerCase().contains('lifetime')) {
              // If max filter is also lifetime, pass; otherwise fail
              return maxWarrantyExtension.toLowerCase().contains('lifetime');
            }
            
            // If max filter is lifetime, all non-lifetime warranties pass
            if (maxWarrantyExtension.toLowerCase().contains('lifetime')) {
              return true;
            }
            
            // Normal numeric comparison
            final extensionMonths = _parseWarrantyToMonths(warrantyExtension);
            final maxExtensionMonths = _parseWarrantyToMonths(maxWarrantyExtension);
            
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
      }      // Apply search if there's an active search query
      if (_searchQuery.isNotEmpty) {
        _products = _allProducts.where((product) {
          final name = (product['name'] ?? '').toString().toLowerCase();

          return name.contains(_searchQuery);
        }).toList();
      } else {
        _products = List.from(_allProducts);
      }

      // Apply sorting if active filters include sorting options
      _applySorting();

      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });
      
      // Check for warranty expiry dates and schedule notifications
      _checkWarrantyExpiryDates(_products);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading products: $e';
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
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _animationController.dispose();
    _searchController.dispose();
    _connectivitySubscription.cancel();
    super.dispose();
  }  String _calculateExpiryDate(String? purchaseDate, String? warrantyPeriod, String? warrantyExtension) {
    if (purchaseDate == null || warrantyPeriod == null) return 'Unknown';
    if (warrantyPeriod.toLowerCase() == 'lifetime') return 'Never expires';
    
    try {
      // Use the notification service for consistent date calculation
      final notificationService = NotificationService();
      final expiryDate = notificationService.calculateExpiryDate(
        purchaseDate, 
        warrantyPeriod, 
        warrantyExtension
      );
      
      if (expiryDate == null) return 'Never expires';
      
      return '${expiryDate.year}-${expiryDate.month.toString().padLeft(2, '0')}-${expiryDate.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
  }

  // Helper method to calculate expiry date specifically for filtering
  DateTime? _calculateExpiryDateForFiltering(Map<String, dynamic> product) {
    final String? purchaseDate = product['purchaseDate'];
    final String? warrantyPeriod = product['warrantyPeriod'];
    final String? warrantyExtension = product['warrantyExtension'];
    
    if (purchaseDate == null || warrantyPeriod == null) return null;
    if (warrantyPeriod.toLowerCase() == 'lifetime') return null; // Lifetime warranties have no expiry
    
    try {
      // Use the notification service for consistent date calculation
      final notificationService = NotificationService();
      return notificationService.calculateExpiryDate(
        purchaseDate, 
        warrantyPeriod, 
        warrantyExtension
      );
    } catch (e) {
      return null;
    }
  }

  bool _isWarrantyExpiringSoon(Map<String, dynamic> product) {
    try {
      final String? warrantyPeriod = product['warrantyPeriod'];
      
      // More robust check for lifetime warranty
      if (warrantyPeriod != null && warrantyPeriod.toLowerCase().contains('lifetime')) {
        return false; // Lifetime warranties never expire
      }
      
      final String? purchaseDate = product['purchaseDate'];
      final String? warrantyExtension = product['warrantyExtension'];
      
      // Check if warranty extension is lifetime
      if (warrantyExtension != null && warrantyExtension.toLowerCase().contains('lifetime')) {
        return false; // Lifetime extension means it never expires
      }
      
      if (purchaseDate == null || warrantyPeriod == null) return false;
      
      // Use the notification service for consistent date calculation
      final notificationService = NotificationService();
      final expiryDate = notificationService.calculateExpiryDate(
        purchaseDate, 
        warrantyPeriod, 
        warrantyExtension
      );
      
      if (expiryDate == null) return false; // Lifetime warranty
      
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
      final String? warrantyExtension = product['warrantyExtension'];
      
      // More robust check for lifetime warranty
      if (warrantyPeriod != null && warrantyPeriod.toLowerCase().contains('lifetime')) {
        return Colors.green; // Lifetime warranties shown in green
      }
      
      // Check if warranty extension is lifetime
      if (warrantyExtension != null && warrantyExtension.toLowerCase().contains('lifetime')) {
        return Colors.green; // Lifetime extension shown in green
      }
      
      final String? purchaseDate = product['purchaseDate'];
      
      if (purchaseDate == null || warrantyPeriod == null) return Colors.black;
      
      // Use the notification service for consistent date calculation
      final notificationService = NotificationService();
      final expiryDate = notificationService.calculateExpiryDate(
        purchaseDate, 
        warrantyPeriod, 
        warrantyExtension
      );
      
      if (expiryDate == null) return Colors.green; // Lifetime warranty
      
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
      
      // Use the notification service for consistent date calculation
      final notificationService = NotificationService();
      final expiryDate = notificationService.calculateExpiryDate(
        purchaseDate, 
        warrantyPeriod, 
        warrantyExtension
      );
      
      if (expiryDate == null) return Colors.green; // Lifetime warranty
      
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
      final String? warrantyExtension = product['warrantyExtension'];
      
      // More robust check for lifetime warranty
      if (warrantyPeriod != null && warrantyPeriod.toLowerCase().contains('lifetime')) {
        return 'LIFETIME'; // Show lifetime badge
      }
      
      // Check if warranty extension is lifetime
      if (warrantyExtension != null && warrantyExtension.toLowerCase().contains('lifetime')) {
        return 'LIFETIME'; // Show lifetime badge for lifetime extension
      }
      
      final String? purchaseDate = product['purchaseDate'];
      
      if (purchaseDate == null || warrantyPeriod == null) return '';
      
      // Use the notification service for consistent date calculation
      final notificationService = NotificationService();
      final expiryDate = notificationService.calculateExpiryDate(
        purchaseDate, 
        warrantyPeriod, 
        warrantyExtension
      );
        if (expiryDate == null) return 'LIFETIME'; // Lifetime warranty
      
      // Normalize dates to midnight for accurate day comparison
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expiryDay = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
      final daysUntilExpiry = expiryDay.difference(today).inDays;
      
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
  void _initializeConnectivity() {
    final connectivityService = ConnectivityService();
    _isConnected = connectivityService.isConnected;
    
    _connectivitySubscription = connectivityService.connectionStream.listen(
      (bool isConnected) {
        if (!mounted) return; // Don't process if widget is not mounted
        
        setState(() {
          _isConnected = isConnected;
        });
        
        // Only show connectivity dialogs if the route is current and stable
        if (!isConnected && !_showingNoInternetDialog && ModalRoute.of(context)?.isCurrent == true) {
          _showNoInternetDialog();
        } else if (isConnected && _showingNoInternetDialog) {
          _hideNoInternetDialog();
        }
      },
    );
  }
  void _showNoInternetDialog() {
    // Não mostra se já está mostrando, contexto não está pronto ou rota não é atual
    if (_showingNoInternetDialog || !mounted || ModalRoute.of(context)?.isCurrent != true) return;
    setState(() {
      _showingNoInternetDialog = true;
    });
    // Delay extra para garantir estabilidade da UI após navegação
    Future.delayed(Duration(milliseconds: 400), () {
      if (!mounted || !_showingNoInternetDialog || ModalRoute.of(context)?.isCurrent != true) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => NoInternetDialog(
          onRetry: () async {
            final hasConnection = await ConnectivityService().hasInternetConnection();
            if (hasConnection) {
              _hideNoInternetDialog();
              await _loadProducts();
            }
          },
        ),
      );
    });
  }
  void _hideNoInternetDialog() {
    if (!_showingNoInternetDialog || !mounted) return;
    setState(() {
      _showingNoInternetDialog = false;
    });
    // Fecha qualquer diálogo aberto de forma segura
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    });
  }void _applySorting() {
    // Check if sorting is explicitly enabled (must be set to 'true')
    if (_activeFilters['sortingEnabled'] != 'true') {
      return; // Skip sorting if not explicitly enabled
    }
    
    if (_activeFilters['sortField']?.isNotEmpty ?? false) {
      final sortField = _activeFilters['sortField']!;
      final isAscending = _activeFilters['sortDirection'] == 'asc';
      _products.sort((a, b) {
        dynamic valueA = _getSortValue(a, sortField);
        dynamic valueB = _getSortValue(b, sortField);
        
        // Handle null values
        if (valueA == null && valueB == null) return 0;
        if (valueA == null) return isAscending ? 1 : -1;
        if (valueB == null) return isAscending ? -1 : 1;
        
        int comparison;
        
        // Handle different data types
        if (valueA is String && valueB is String) {
          comparison = valueA.toLowerCase().compareTo(valueB.toLowerCase());
        } else if (valueA is num && valueB is num) {
          comparison = valueA.compareTo(valueB);
        } else if (valueA is DateTime && valueB is DateTime) {
          comparison = valueA.compareTo(valueB);
        } else {
          // Convert to string for comparison
          comparison = valueA.toString().toLowerCase().compareTo(valueB.toString().toLowerCase());
        }
        
        return isAscending ? comparison : -comparison;
      });
    }
  }
  dynamic _getSortValue(Map<String, dynamic> product, String sortField) {
    switch (sortField) {
      case 'name':
        return product['name']?.toString() ?? '';
      case 'price':
        return _parsePrice(product['price']?.toString() ?? '0');
      case 'purchaseDate':
        return DateTime.tryParse(product['purchaseDate'] ?? '') ?? DateTime(1900);      case 'expiryDate':
        // Use the helper method to calculate expiry date for sorting
        final expiryDate = _calculateExpiryDateForFiltering(product);
        return expiryDate ?? DateTime(2100); // Put lifetime warranties at end when sorting ascending
      case 'lastUpdated':
        // Handle both createdAt and lastUpdated fields
        final lastUpdated = product['UpdatedAt'] ?? product['createdAt'];
        if (lastUpdated is Timestamp) {
          return lastUpdated.toDate();
        } else if (lastUpdated is String) {
          return DateTime.tryParse(lastUpdated) ?? DateTime(1900);
        }
        return DateTime(1900);
      case 'warrantyPeriod':
        return _parseWarrantyToMonths(product['warrantyPeriod'] ?? '0');
      case 'warrantyExtension':
        return _parseWarrantyToMonths(product['warrantyExtension'] ?? '0');
      case 'category':
        return product['category']?.toString() ?? '';
      case 'brand':
        return product['brand']?.toString() ?? '';
      case 'storeDetails':
        return product['storeDetails']?.toString() ?? '';
      default:
        return product[sortField]?.toString() ?? '';
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
      return StatisticsPage();    } else if (_currentIndex == 2) {
      return FilterPage(
        onApplyFilters: (filters) {
          _handleFilters(filters);
          setState(() => _currentIndex = 0); // Return to list view after applying filters
        },
        activeFilters: _activeFilters,
        onBackPressed: () {
          // Handle back button to return to the previous tab (list view)
          setState(() => _currentIndex = 0);
        },
      );
    } else if (_currentIndex == 3) {
      return ProfilePage();
    }    // Return the main list view for other tabs
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
                                        padding: const EdgeInsets.all(16.0),                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                ClipRRect(
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: _buildImageWidget(product),
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
                                                      ),                                                      Text(
                                                        'Extension: ${product['warrantyExtension'] ?? 'None'}',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Expires: ${_calculateExpiryDate(product['purchaseDate'], product['warrantyPeriod'], product['warrantyExtension'])}',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 16,
                                                          color: _getExpiryTextColor(product),
                                                          fontWeight: _isWarrantyExpiringSoon(product) ? FontWeight.bold : FontWeight.normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),                                            if (_isWarrantyExpiringSoon(product))
                                              Padding(
                                                padding: const EdgeInsets.only(top: 12.0),
                                                child: Align(
                                                  alignment: Alignment.bottomRight,
                                                  child: Container(
                                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: _getExpiryBadgeColor(product),
                                                      borderRadius: BorderRadius.circular(16),
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
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ), // End GestureDetector
                                );
                              }, // End ListView.builder
                            ), // End Expanded
        )], // End children of Column
        ), // End Column
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
                        if (_searchQuery.isEmpty) {
                          _products = List.from(_allProducts);
                        } else {
                          _products = _allProducts.where((product) {
                            final name = (product['name'] ?? '').toString().toLowerCase();
                            return name.contains(_searchQuery);
                          }).toList();
                        }
                      });
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
  }  Widget _buildImageWidget(Map<String, dynamic> product) {
    // Check if we have a local image path
    final String? localPath = product['imagePath'];
    
    // If local path is available and file exists, use it
    if (localPath != null && localPath.isNotEmpty) {
      final File localFile = File(localPath);
      
      // Return a FutureBuilder to check if file exists
      return FutureBuilder<bool>(
        future: localFile.exists(),
        builder: (context, snapshot) {          if (snapshot.connectionState == ConnectionState.done && 
              snapshot.hasData && 
              snapshot.data == true) {            // Local file exists, use adaptive container for both horizontal and vertical images
            return Container(
              width: 150,
              constraints: BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  localFile,
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) {
                    // Fall back to remote URL if there's an error
                    return _buildRemoteImageFallback(product);
                  },
                ),
              ),
            );} else {
            // If local file doesn't exist, fall back to remote URL
            return _buildRemoteImageFallback(product);
          }
        },
      );
    } else {
      // No local path, use remote image
      return _buildRemoteImageFallback(product);
    }
  }  Widget _buildRemoteImageFallback(Map<String, dynamic> product) {    // Display placeholder with adaptive sizing for both horizontal and vertical orientations
    return Container(
      width: 150,
      constraints: BoxConstraints(minHeight: 150),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.image, size: 40, color: Colors.grey.shade400),
    );
  }
} // End of _ListPageState class

