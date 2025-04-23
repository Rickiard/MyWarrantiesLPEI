import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';
import 'addProduct.dart';

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
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  
  late ScrollController _scrollController;
  late AnimationController _animationController;
  bool _isSearchBarCollapsed = false;
  bool _isBottomBarCollapsed = false;
  double _lastScrollPosition = 0;
  String _searchQuery = '';

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
      _searchQuery = _searchController.text.toLowerCase();
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
      });
    }
  }

  Future<void> _loadProducts() async {
    if (_auth.currentUser == null) {
      setState(() {
        _errorMessage = 'Please log in to view your products';
        _isLoading = false;
      });
      return;
    }

    try {
      final userDoc = _firestore.collection('users').doc(_auth.currentUser!.uid);
      
      // Check if user document exists
      final userSnapshot = await userDoc.get();
      if (!userSnapshot.exists) {
        // Create user document if it doesn't exist
        await userDoc.set({
          'id': _auth.currentUser!.uid,
          'email': _auth.currentUser!.email,
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      final productsCollection = userDoc.collection('products');
      
      // Check if products collection exists and has any documents
      final productsSnapshot = await productsCollection.limit(1).get();
      if (productsSnapshot.docs.isEmpty) {
        // Create initial product to demonstrate the structure
        await productsCollection.add({
          'name': 'Xiaomi POCO X7 Pro',
          'warrantyStatus': 'Active',
          'expiryDate': '2028-03-27',
          'imageUrl': 'https://i02.appmifile.com/984_operator_sg/10/03/2023/ce8d1176372346a1923b24c53ad5a287.png',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Listen to real-time updates
      productsCollection.snapshots().listen((snapshot) {
        setState(() {
          _products = snapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data(),
          }).toList();
          
          // Filter products if there's a search query
          if (_searchQuery.isNotEmpty) {
            _products = _products.where((product) {
              final name = (product['name'] ?? '').toString().toLowerCase();
              final warrantyStatus = (product['warrantyStatus'] ?? '').toString().toLowerCase();
              return name.contains(_searchQuery) || warrantyStatus.contains(_searchQuery);
            }).toList();
          }
          
          _isLoading = false;
        });
      }, onError: (e) {
        setState(() {
          _errorMessage = 'Error loading products: $e';
          _isLoading = false;
        });
      });
    } catch (e) {
      print('Error setting up products: $e');
      setState(() {
        _errorMessage = 'Error setting up products: $e';
        _isLoading = false;
      });
    }
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
      print('Error checking login status: $e');
      setState(() {
        _errorMessage = 'Error initializing app: $e';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAFE1F0),
      body: SafeArea(
        child: Stack(
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
                              ? const Center(
                                  child: Text(
                                    'No products found',
                                    style: TextStyle(fontSize: 18),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  itemCount: _products.length,
                                  itemBuilder: (context, index) {
                                    final product = _products[index];
                                    return Padding(
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
                                                      'Warranty ${product['warrantyStatus'] ?? 'Unknown'}',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 18,
                                                      ),
                                                    ),
                                                    Text(
                                                      'Expires: ${product['expiryDate'] ?? 'Unknown'}',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
            // Animated Search Bar
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
        ),
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
                        color: _selectedIndex == 0 ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => setState(() => _selectedIndex = 0),
                    ),
                    IconButton(
                      icon: Icon(Icons.bar_chart,
                        color: _selectedIndex == 1 ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => setState(() => _selectedIndex = 1),
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
                    IconButton(
                      icon: Icon(Icons.filter_list,
                        color: _selectedIndex == 2 ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => setState(() => _selectedIndex = 2),
                    ),
                    IconButton(
                      icon: Icon(Icons.person_outline,
                        color: _selectedIndex == 3 ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () => setState(() => _selectedIndex = 3),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
