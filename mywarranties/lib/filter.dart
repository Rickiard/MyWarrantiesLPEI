import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mywarranties/list.dart';

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
  String _minWarrantyPeriodUnit = 'days';
  String _maxWarrantyPeriodUnit = 'days';
  
  // Warranty extension range controllers
  final _minWarrantyExtensionController = TextEditingController();
  final _maxWarrantyExtensionController = TextEditingController();
  String _minWarrantyExtensionUnit = 'days';
  String _maxWarrantyExtensionUnit = 'days';
  
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
  final List<Map<String, dynamic>> _sortFields = [
    {'value': 'name', 'label': 'Product Name', 'icon': Icons.text_fields},
    {'value': 'price', 'label': 'Price', 'icon': Icons.attach_money},
    {'value': 'purchaseDate', 'label': 'Purchase Date', 'icon': Icons.calendar_today},
    {'value': 'warrantyPeriod', 'label': 'Warranty Period', 'icon': Icons.access_time},
    {'value': 'warrantyExtension', 'label': 'Warranty Extension', 'icon': Icons.extension},
    {'value': 'category', 'label': 'Category', 'icon': Icons.category},
    {'value': 'brand', 'label': 'Brand', 'icon': Icons.branding_watermark},
    {'value': 'storeDetails', 'label': 'Store', 'icon': Icons.store},
  ];

  // Time units
  final List<String> _timeUnits = ['days', 'months', 'years', 'lifetime'];

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
        // Load text filters
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
        
        // Load warranty period range with lifetime handling
        if (widget.activeFilters!['minWarrantyPeriod']?.isNotEmpty ?? false) {
          if (widget.activeFilters!['minWarrantyPeriod']!.toLowerCase() == 'lifetime') {
            _minWarrantyPeriodController.text = 'Lifetime';
            _minWarrantyPeriodUnit = 'lifetime';
          } else {
            final parts = widget.activeFilters!['minWarrantyPeriod']!.toLowerCase().split(' ');
            if (parts.length == 2) {
              _minWarrantyPeriodController.text = parts[0];
              _minWarrantyPeriodUnit = parts[1];
            }
          }
        }
        if (widget.activeFilters!['maxWarrantyPeriod']?.isNotEmpty ?? false) {
          if (widget.activeFilters!['maxWarrantyPeriod']!.toLowerCase() == 'lifetime') {
            _maxWarrantyPeriodController.text = 'Lifetime';
            _maxWarrantyPeriodUnit = 'lifetime';
          } else {
            final parts = widget.activeFilters!['maxWarrantyPeriod']!.toLowerCase().split(' ');
            if (parts.length == 2) {
              _maxWarrantyPeriodController.text = parts[0];
              _maxWarrantyPeriodUnit = parts[1];
            }
          }
        }
        
        // Load warranty extension range with lifetime handling
        if (widget.activeFilters!['minWarrantyExtension']?.isNotEmpty ?? false) {
          if (widget.activeFilters!['minWarrantyExtension']!.toLowerCase() == 'lifetime') {
            _minWarrantyExtensionController.text = 'Lifetime';
            _minWarrantyExtensionUnit = 'lifetime';
          } else {
            final parts = widget.activeFilters!['minWarrantyExtension']!.toLowerCase().split(' ');
            if (parts.length == 2) {
              _minWarrantyExtensionController.text = parts[0];
              _minWarrantyExtensionUnit = parts[1];
            }
          }
        }
        if (widget.activeFilters!['maxWarrantyExtension']?.isNotEmpty ?? false) {
          if (widget.activeFilters!['maxWarrantyExtension']!.toLowerCase() == 'lifetime') {
            _maxWarrantyExtensionController.text = 'Lifetime';
            _maxWarrantyExtensionUnit = 'lifetime';
          } else {
            final parts = widget.activeFilters!['maxWarrantyExtension']!.toLowerCase().split(' ');
            if (parts.length == 2) {
              _maxWarrantyExtensionController.text = parts[0];
              _maxWarrantyExtensionUnit = parts[1];
            }
          }
        }
        
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
      // Format warranty period with units
      String minWarrantyPeriod = '';
      String maxWarrantyPeriod = '';
      if (_minWarrantyPeriodUnit == 'lifetime') {
        minWarrantyPeriod = 'lifetime';
      } else if (_minWarrantyPeriodController.text.isNotEmpty) {
        minWarrantyPeriod = '${_minWarrantyPeriodController.text} ${_minWarrantyPeriodUnit}';
      }
      if (_maxWarrantyPeriodUnit == 'lifetime') {
        maxWarrantyPeriod = 'lifetime';
      } else if (_maxWarrantyPeriodController.text.isNotEmpty) {
        maxWarrantyPeriod = '${_maxWarrantyPeriodController.text} ${_maxWarrantyPeriodUnit}';
      }

      // Format warranty extension with units
      String minWarrantyExtension = '';
      String maxWarrantyExtension = '';
      if (_minWarrantyExtensionUnit == 'lifetime') {
        minWarrantyExtension = 'lifetime';
      } else if (_minWarrantyExtensionController.text.isNotEmpty) {
        minWarrantyExtension = '${_minWarrantyExtensionController.text} ${_minWarrantyExtensionUnit}';
      }
      if (_maxWarrantyExtensionUnit == 'lifetime') {
        maxWarrantyExtension = 'lifetime';
      } else if (_maxWarrantyExtensionController.text.isNotEmpty) {
        maxWarrantyExtension = '${_maxWarrantyExtensionController.text} ${_maxWarrantyExtensionUnit}';
      }

      final filters = {
        'name': _nameController.text.trim(),
        'minPrice': _minPriceController.text.trim(),
        'maxPrice': _maxPriceController.text.trim(),
        'startDate': _startDateController.text,
        'endDate': _endDateController.text,
        'minWarrantyPeriod': minWarrantyPeriod,
        'maxWarrantyPeriod': maxWarrantyPeriod,
        'minWarrantyExtension': minWarrantyExtension,
        'maxWarrantyExtension': maxWarrantyExtension,
        'categories': _selectedCategories.isEmpty ? '' : _selectedCategories.join(','),
        'brands': _selectedBrands.isEmpty ? '' : _selectedBrands.join(','),
        'stores': _selectedStores.isEmpty ? '' : _selectedStores.join(','),
        'sortField': _selectedSortField,
        'sortDirection': _sortAscending ? 'asc' : 'desc',
      };

      // Check if any filters are active
      bool hasActiveFilters = filters.values.any((value) => value.isNotEmpty);
      
      setState(() {
        _hasActiveFilters = hasActiveFilters;
      });

      widget.onApplyFilters(filters);
      
      // Show snackbar indicating filters were applied
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
      // Clear all text controllers
      _nameController.text = '';
      _minPriceController.text = '';
      _maxPriceController.text = '';
      _startDateController.text = '';
      _endDateController.text = '';
      _minWarrantyPeriodController.text = '';
      _maxWarrantyPeriodController.text = '';
      _minWarrantyExtensionController.text = '';
      _maxWarrantyExtensionController.text = '';

      // Reset date range
      _startDate = null;
      _endDate = null;

      // Clear multiple selections
      _selectedCategories = [];
      _selectedBrands = [];
      _selectedStores = [];

      // Reset sorting options to defaults
      _selectedSortField = 'name';
      _sortAscending = true;

      // Reset active filters flag
      _hasActiveFilters = false;
    });

    // Apply empty filters
    widget.onApplyFilters({
      'name': '',
      'minPrice': '',
      'maxPrice': '',
      'startDate': '',
      'endDate': '',
      'minWarrantyPeriod': '',
      'maxWarrantyPeriod': '',
      'minWarrantyExtension': '',
      'maxWarrantyExtension': '',
      'categories': '',
      'brands': '',
      'stores': '',
      'sortField': 'name',
      'sortDirection': 'asc',
    });

    // Show a snackbar indicating filters were cleared
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('All filters cleared'),
        backgroundColor: Colors.blue,
      ),
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ListPage()),
    );
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
            const Text('Filter Products'),
            if (_hasActiveFilters)
              Container(
                margin: EdgeInsets.only(left: 8),
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
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
                  labelStyle: TextStyle(color: Colors.grey[700]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Filters Section
              _buildSectionHeader('Categories'),
              const SizedBox(height: 8),
              _buildFilterChipsContainer(_categories, _selectedCategories, (category, selected) {
                setState(() {
                  if (selected) {
                    _selectedCategories.add(category);
                  } else {
                    _selectedCategories.remove(category);
                  }
                });
              }),
              const SizedBox(height: 24),

              _buildSectionHeader('Price Range'),
              const SizedBox(height: 8),
              _buildRangeFields(
                _minPriceController,
                _maxPriceController,
                'Min Price',
                'Max Price',
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Purchase Date Range'),
              const SizedBox(height: 8),
              _buildDateRangeFields(),
              const SizedBox(height: 24),

              _buildSectionHeader('Warranty Period Range'),
              const SizedBox(height: 8),
              _buildWarrantyRangeFields(
                _minWarrantyPeriodController,
                _maxWarrantyPeriodController,
                _minWarrantyPeriodUnit,
                _maxWarrantyPeriodUnit,
                (value) => setState(() => _minWarrantyPeriodUnit = value ?? 'days'),
                (value) => setState(() => _maxWarrantyPeriodUnit = value ?? 'days'),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Stores'),
              const SizedBox(height: 8),
              _buildFilterChipsContainer(_stores, _selectedStores, (store, selected) {
                setState(() {
                  if (selected) {
                    _selectedStores.add(store);
                  } else {
                    _selectedStores.remove(store);
                  }
                });
              }),
              const SizedBox(height: 24),

              _buildSectionHeader('Brands'),
              const SizedBox(height: 8),
              _buildFilterChipsContainer(_brands, _selectedBrands, (brand, selected) {
                setState(() {
                  if (selected) {
                    _selectedBrands.add(brand);
                  } else {
                    _selectedBrands.remove(brand);
                  }
                });
              }),
              const SizedBox(height: 24),

              _buildSectionHeader('Warranty Extension Range'),
              const SizedBox(height: 8),
              _buildWarrantyRangeFields(
                _minWarrantyExtensionController,
                _maxWarrantyExtensionController,
                _minWarrantyExtensionUnit,
                _maxWarrantyExtensionUnit,
                (value) => setState(() => _minWarrantyExtensionUnit = value ?? 'days'),
                (value) => setState(() => _maxWarrantyExtensionUnit = value ?? 'days'),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Sort By'),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: DropdownButtonFormField<String>(
                        value: _selectedSortField,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: _sortFields.map((field) {
                          return DropdownMenuItem<String>(
                            value: field['value'],
                            child: Row(
                              children: [
                                Icon(field['icon'], color: Colors.blue, size: 20),
                                const SizedBox(width: 12),
                                Text(
                                  field['label']!,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedSortField = value ?? 'name';
                          });
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildSortDirectionButton(
                                true,
                                Icons.arrow_upward,
                                'Ascending',
                                isLeft: true,
                              ),
                            ),
                            Expanded(
                              child: _buildSortDirectionButton(
                                false,
                                Icons.arrow_downward,
                                'Descending',
                                isLeft: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _clearFilters,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'CLEAR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'APPLY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
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

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildFilterChipsContainer(
    List<String> items,
    List<String> selectedItems,
    void Function(String, bool) onSelected,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final isSelected = selectedItems.contains(item);
          return FilterChip(
            selected: isSelected,
            label: Text(item),
            backgroundColor: Colors.white,
            selectedColor: Colors.blue.shade100,
            checkmarkColor: Colors.blue,
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: (selected) => onSelected(item, selected),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRangeFields(
    TextEditingController minController,
    TextEditingController maxController,
    String minLabel,
    String maxLabel,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: minController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              labelText: minLabel,
              labelStyle: TextStyle(color: Colors.grey[700]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: maxController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              labelText: maxLabel,
              labelStyle: TextStyle(color: Colors.grey[700]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateRangeFields() {
    return Row(
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
              labelStyle: TextStyle(color: Colors.grey[700]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _endDateController,
            readOnly: true,
            onTap: () => _selectEndDate(context),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              labelText: 'To',
              labelStyle: TextStyle(color: Colors.grey[700]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarrantyRangeFields(
    TextEditingController minController,
    TextEditingController maxController,
    String minUnit,
    String maxUnit,
    void Function(String?) onMinUnitChanged,
    void Function(String?) onMaxUnitChanged,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Minimum'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'Value',
                        labelStyle: TextStyle(color: Colors.grey[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildUnitDropdown(minUnit, onMinUnitChanged),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Maximum'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        labelText: 'Value',
                        labelStyle: TextStyle(color: Colors.grey[700]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildUnitDropdown(maxUnit, onMaxUnitChanged),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnitDropdown(String value, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: _timeUnits.map((unit) {
        return DropdownMenuItem(
          value: unit,
          child: Text(unit.substring(0, 1).toUpperCase() + unit.substring(1)),
        );
      }).toList(),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      onChanged: onChanged,
    );
  }

  Widget _buildSortDirectionButton(bool isAscending, IconData icon, String label, {required bool isLeft}) {
    final isSelected = _sortAscending == isAscending;
    return InkWell(
      onTap: () {
        setState(() {
          _sortAscending = isAscending;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: isLeft ? const Radius.circular(10) : Radius.zero,
            right: !isLeft ? const Radius.circular(10) : Radius.zero,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade700,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
