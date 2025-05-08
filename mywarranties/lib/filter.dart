import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FilterPage extends StatefulWidget {
  final Function(Map<String, String>) onApplyFilters;
  final Map<String, String>? activeFilters; // Para receber os filtros ativos

  const FilterPage({
    Key? key, 
    required this.onApplyFilters, 
    this.activeFilters,
  }) : super(key: key);

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  // Range filter controllers
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  
  // Date range controllers
  DateTime? _startDate;
  DateTime? _endDate;
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  
  // Warranty period range controllers
  final _minWarrantyPeriodController = TextEditingController();
  final _maxWarrantyPeriodController = TextEditingController();
  
  // Warranty extension range controllers
  final _minWarrantyExtensionController = TextEditingController();
  final _maxWarrantyExtensionController = TextEditingController();
  
  // Multiple selection controllers
  List<String> _selectedCategories = [];
  List<String> _selectedBrands = [];
  List<String> _selectedStores = [];
  
  // Sorting options
  String _selectedSortField = 'name';
  bool _sortAscending = true;
  
  // Available options
  List<String> _categories = [];
  List<String> _brands = [];
  List<String> _stores = [];
  bool _hasActiveFilters = false;
  
  // Available sorting fields
  final List<Map<String, String>> _sortFields = [
    {'value': 'name', 'label': 'Product Name'},
    {'value': 'price', 'label': 'Price'},
    {'value': 'purchaseDate', 'label': 'Purchase Date'},
    {'value': 'warrantyPeriod', 'label': 'Warranty Period'},
    {'value': 'warrantyExtension', 'label': 'Warranty Extension'},
    {'value': 'category', 'label': 'Category'},
    {'value': 'brand', 'label': 'Brand'},
    {'value': 'storeDetails', 'label': 'Store'},
  ];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _loadActiveFilters();
  }

  Future<void> _loadFilterOptions() async {
    // Fetch unique categories, brands, and stores from the product list
    final products = await FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser?.uid)
        .collection('products')
        .get();

    final categories = <String>{};
    final brands = <String>{};
    final stores = <String>{};

    for (var doc in products.docs) {
      categories.add(doc['category'] ?? '');
      brands.add(doc['brand'] ?? '');
      stores.add(doc['storeDetails'] ?? '');
    }

    setState(() {
      _categories = categories.where((e) => e.isNotEmpty).toList();
      _brands = brands.where((e) => e.isNotEmpty).toList();
      _stores = stores.where((e) => e.isNotEmpty).toList();
    });
  }

  void _loadActiveFilters() {
    if (widget.activeFilters != null) {
      setState(() {
        _nameController.text = widget.activeFilters!['name'] ?? '';
        
        // Load price range
        _minPriceController.text = widget.activeFilters!['minPrice'] ?? '';
        _maxPriceController.text = widget.activeFilters!['maxPrice'] ?? '';
        
        // Load date range
        if (widget.activeFilters!['startDate']?.isNotEmpty ?? false) {
          _startDateController.text = widget.activeFilters!['startDate'] ?? '';
          _startDate = DateTime.tryParse(widget.activeFilters!['startDate'] ?? '');
        }
        if (widget.activeFilters!['endDate']?.isNotEmpty ?? false) {
          _endDateController.text = widget.activeFilters!['endDate'] ?? '';
          _endDate = DateTime.tryParse(widget.activeFilters!['endDate'] ?? '');
        }
        
        // Load warranty period range
        _minWarrantyPeriodController.text = widget.activeFilters!['minWarrantyPeriod'] ?? '';
        _maxWarrantyPeriodController.text = widget.activeFilters!['maxWarrantyPeriod'] ?? '';
        
        // Load warranty extension range
        _minWarrantyExtensionController.text = widget.activeFilters!['minWarrantyExtension'] ?? '';
        _maxWarrantyExtensionController.text = widget.activeFilters!['maxWarrantyExtension'] ?? '';
        
        // Load multiple selections
        if (widget.activeFilters!['categories']?.isNotEmpty ?? false) {
          _selectedCategories = widget.activeFilters!['categories']!.split(',');
        }
        if (widget.activeFilters!['brands']?.isNotEmpty ?? false) {
          _selectedBrands = widget.activeFilters!['brands']!.split(',');
        }
        if (widget.activeFilters!['stores']?.isNotEmpty ?? false) {
          _selectedStores = widget.activeFilters!['stores']!.split(',');
        }
        
        // Load sorting options
        _selectedSortField = widget.activeFilters!['sortField'] ?? 'name';
        _sortAscending = widget.activeFilters!['sortDirection'] == 'desc' ? false : true;
        
        _hasActiveFilters = widget.activeFilters!.values.any((value) => value.isNotEmpty);
      });
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _applyFilters() {
    if (_formKey.currentState!.validate()) {
      final filters = {
        'name': _nameController.text,
        // Price range
        'minPrice': _minPriceController.text,
        'maxPrice': _maxPriceController.text,
        // Date range
        'startDate': _startDateController.text,
        'endDate': _endDateController.text,
        // Warranty period range
        'minWarrantyPeriod': _minWarrantyPeriodController.text,
        'maxWarrantyPeriod': _maxWarrantyPeriodController.text,
        // Warranty extension range
        'minWarrantyExtension': _minWarrantyExtensionController.text,
        'maxWarrantyExtension': _maxWarrantyExtensionController.text,
        // Multiple selections
        'categories': _selectedCategories.isEmpty ? '' : _selectedCategories.join(','),
        'brands': _selectedBrands.isEmpty ? '' : _selectedBrands.join(','),
        'stores': _selectedStores.isEmpty ? '' : _selectedStores.join(','),
        // Sorting options
        'sortField': _selectedSortField,
        'sortDirection': _sortAscending ? 'asc' : 'desc',
      };

      // Verificar se há algum filtro ativo
      bool hasActiveFilters = filters.values.any((value) => value.isNotEmpty);
      
      setState(() {
        _hasActiveFilters = hasActiveFilters;
      });

      widget.onApplyFilters(filters);
      
      // Mostrar snackbar indicando que os filtros foram aplicados
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasActiveFilters ? 'Filters applied successfully!' : 'All filters cleared'),
          backgroundColor: hasActiveFilters ? Colors.green : Colors.blue,
        ),
      );
    }
  }

  void _clearFilters() {
    setState(() {
      _nameController.clear();
      
      // Clear price range
      _minPriceController.clear();
      _maxPriceController.clear();
      
      // Clear date range
      _startDateController.clear();
      _endDateController.clear();
      _startDate = null;
      _endDate = null;
      
      // Clear warranty period range
      _minWarrantyPeriodController.clear();
      _maxWarrantyPeriodController.clear();
      
      // Clear warranty extension range
      _minWarrantyExtensionController.clear();
      _maxWarrantyExtensionController.clear();
      
      // Clear multiple selections
      _selectedCategories.clear();
      _selectedBrands.clear();
      _selectedStores.clear();
      
      // Reset sorting options to defaults
      _selectedSortField = 'name';
      _sortAscending = true;
      
      _hasActiveFilters = false;
    });

    // Aplicar filtros limpos
    widget.onApplyFilters({});

    // Fechar a página
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    
    // Dispose price range controllers
    _minPriceController.dispose();
    _maxPriceController.dispose();
    
    // Dispose date range controllers
    _startDateController.dispose();
    _endDateController.dispose();
    
    // Dispose warranty period range controllers
    _minWarrantyPeriodController.dispose();
    _maxWarrantyPeriodController.dispose();
    
    // Dispose warranty extension range controllers
    _minWarrantyExtensionController.dispose();
    _maxWarrantyExtensionController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAFE1F0),
      appBar: AppBar(
        title: Row(
          children: [
            Text('Filter Products'),
            if (_hasActiveFilters)
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Product Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Category Multi-Select
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categories',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((category) {
                        final isSelected = _selectedCategories.contains(category);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(category),
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue.shade100,
                          checkmarkColor: Colors.blue,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedCategories.add(category);
                              } else {
                                _selectedCategories.remove(category);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Price Range
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Price Range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Min Price',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Max Price',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Purchase Date Range
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase Date Range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _startDateController,
                          readOnly: true,
                          onTap: () => _selectStartDate(context),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'From',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _endDateController,
                          readOnly: true,
                          onTap: () => _selectEndDate(context),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'To',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Warranty Period Range
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warranty Period Range (months)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minWarrantyPeriodController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Min',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _maxWarrantyPeriodController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Max',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Store Multi-Select
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stores',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _stores.map((store) {
                        final isSelected = _selectedStores.contains(store);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(store),
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue.shade100,
                          checkmarkColor: Colors.blue,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedStores.add(store);
                              } else {
                                _selectedStores.remove(store);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Brand Multi-Select
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Brands',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _brands.map((brand) {
                        final isSelected = _selectedBrands.contains(brand);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(brand),
                          backgroundColor: Colors.white,
                          selectedColor: Colors.blue.shade100,
                          checkmarkColor: Colors.blue,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedBrands.add(brand);
                              } else {
                                _selectedBrands.remove(brand);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Warranty Extension Range
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warranty Extension Range (months)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minWarrantyExtensionController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Min',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _maxWarrantyExtensionController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Max',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              
              // Sort Options
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _selectedSortField,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            labelText: 'Sort Field',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          items: _sortFields.map((field) {
                            return DropdownMenuItem<String>(
                              value: field['value'],
                              child: Text(field['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSortField = value ?? 'name';
                            });
                          },
                        ),
                        Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Text('Sort Direction:'),
                              Spacer(),
                              ToggleButtons(
                                borderRadius: BorderRadius.circular(8),
                                selectedBorderColor: Colors.blue,
                                selectedColor: Colors.white,
                                fillColor: Colors.blue,
                                color: Colors.grey[600],
                                constraints: BoxConstraints(minHeight: 36, minWidth: 80),
                                isSelected: [_sortAscending, !_sortAscending],
                                onPressed: (index) {
                                  setState(() {
                                    _sortAscending = index == 0;
                                  });
                                },
                                children: [
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('A to Z'),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('Z to A'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Apply and Clear Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _clearFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black87,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'CLEAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'APPLY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
