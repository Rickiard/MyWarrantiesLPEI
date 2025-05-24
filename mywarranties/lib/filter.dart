import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mywarranties/list.dart';

class FilterPage extends StatefulWidget {
  final Function(Map<String, String>) onApplyFilters;
  final Map<String, String>? activeFilters; // Para receber os filtros ativos
  final VoidCallback? onBackPressed; // Callback para lidar com o botão de voltar

  const FilterPage({
    Key? key, 
    required this.onApplyFilters, 
    this.activeFilters,
    this.onBackPressed,
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
    // Validate all form fields
    if (_formKey.currentState!.validate()) {
      try {
        // Format warranty period with units
        String minWarrantyPeriod = '';
        String maxWarrantyPeriod = '';
        if (_minWarrantyPeriodUnit == 'lifetime') {
          minWarrantyPeriod = 'lifetime';
        } else if (_minWarrantyPeriodController.text.isNotEmpty) {
          // Validate numeric input
          if (int.tryParse(_minWarrantyPeriodController.text) != null) {
            minWarrantyPeriod = '${_minWarrantyPeriodController.text} ${_minWarrantyPeriodUnit}';
          }
        }
        if (_maxWarrantyPeriodUnit == 'lifetime') {
          maxWarrantyPeriod = 'lifetime';
        } else if (_maxWarrantyPeriodController.text.isNotEmpty) {
          // Validate numeric input
          if (int.tryParse(_maxWarrantyPeriodController.text) != null) {
            maxWarrantyPeriod = '${_maxWarrantyPeriodController.text} ${_maxWarrantyPeriodUnit}';
          }
        }

        // Format warranty extension with units
        String minWarrantyExtension = '';
        String maxWarrantyExtension = '';
        if (_minWarrantyExtensionUnit == 'lifetime') {
          minWarrantyExtension = 'lifetime';
        } else if (_minWarrantyExtensionController.text.isNotEmpty) {
          // Validate numeric input
          if (int.tryParse(_minWarrantyExtensionController.text) != null) {
            minWarrantyExtension = '${_minWarrantyExtensionController.text} ${_minWarrantyExtensionUnit}';
          }
        }
        if (_maxWarrantyExtensionUnit == 'lifetime') {
          maxWarrantyExtension = 'lifetime';
        } else if (_maxWarrantyExtensionController.text.isNotEmpty) {
          // Validate numeric input
          if (int.tryParse(_maxWarrantyExtensionController.text) != null) {
            maxWarrantyExtension = '${_maxWarrantyExtensionController.text} ${_maxWarrantyExtensionUnit}';
          }
        }

        // Validate price inputs
        String minPrice = '';
        String maxPrice = '';
        if (_minPriceController.text.isNotEmpty) {
          // Ensure it's a valid number
          if (double.tryParse(_minPriceController.text) != null) {
            minPrice = _minPriceController.text.trim();
          }
        }
        if (_maxPriceController.text.isNotEmpty) {
          // Ensure it's a valid number
          if (double.tryParse(_maxPriceController.text) != null) {
            maxPrice = _maxPriceController.text.trim();
          }
        }

        // Validate date range
        String startDate = _startDateController.text;
        String endDate = _endDateController.text;
        if (startDate.isNotEmpty && endDate.isNotEmpty) {
          final start = DateTime.tryParse(startDate);
          final end = DateTime.tryParse(endDate);
          if (start != null && end != null && start.isAfter(end)) {
            // Invalid date range, reset dates
            startDate = '';
            endDate = '';
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Invalid date range: Start date must be before end date'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }
        }

        final filters = {
          'name': _nameController.text.trim(),
          'minPrice': minPrice,
          'maxPrice': maxPrice,
          'startDate': startDate,
          'endDate': endDate,
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
            duration: Duration(seconds: 2),
          ),
        );
      } catch (e) {
        // Handle any unexpected errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error applying filters: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      // Form validation failed, show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix the errors in the form before applying filters'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
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
      backgroundColor: const Color(0xFFAFE1F0),      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Use the provided callback if available, otherwise fall back to Navigator.pop()
            if (widget.onBackPressed != null) {
              widget.onBackPressed!();
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
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
              _buildFilterChipsContainer(
                _categories, 
                _selectedCategories, 
                (category, selected) => _updateSelectedCategories(category, selected)
              ),
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
                (value) => _updateMinWarrantyPeriodUnit(value),
                (value) => _updateMaxWarrantyPeriodUnit(value),
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Stores'),
              const SizedBox(height: 8),
              _buildFilterChipsContainer(
                _stores, 
                _selectedStores, 
                (store, selected) => _updateSelectedStores(store, selected)
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Brands'),
              const SizedBox(height: 8),
              _buildFilterChipsContainer(
                _brands, 
                _selectedBrands, 
                (brand, selected) => _updateSelectedBrands(brand, selected)
              ),
              const SizedBox(height: 24),

              _buildSectionHeader('Warranty Extension Range'),
              const SizedBox(height: 8),
              _buildWarrantyRangeFields(
                _minWarrantyExtensionController,
                _maxWarrantyExtensionController,
                _minWarrantyExtensionUnit,
                _maxWarrantyExtensionUnit,
                (value) => _updateMinWarrantyExtensionUnit(value),
                (value) => _updateMaxWarrantyExtensionUnit(value),
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
                ]);
              }
                          ),
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
      padding: const EdgeInsets.all(8),
      constraints: BoxConstraints(
        minHeight: 50,
        maxHeight: 200, // Altura máxima para evitar overflow vertical extremo
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.start,
              children: items.map((item) {
                final isSelected = selectedItems.contains(item);
                return FilterChip(
                  selected: isSelected,
                  label: Text(
                    item,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? Colors.blue : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: Colors.white,
                  selectedColor: Colors.blue.shade100,
                  checkmarkColor: Colors.blue,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (selected) => onSelected(item, selected),
                );
              }).toList(),
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'No options available',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 13,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeFields(
    TextEditingController minController,
    TextEditingController maxController,
    String minLabel,
    String maxLabel,
  ) {
    // Use LayoutBuilder para adaptar-se ao espaço disponível
    return LayoutBuilder(
      builder: (context, constraints) {
        // Em telas muito pequenas, empilhe os campos verticalmente
        if (constraints.maxWidth < 400) {
          return Column(
            children: [
              TextFormField(
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
                  errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  helperText: ' ', // Adds space for error message
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Check if input is a valid number
                    if (double.tryParse(value) == null) {
                      return 'Enter a valid number';
                    }
                    
                    // Check if input is non-negative
                    if (double.parse(value) < 0) {
                      return 'Must be non-negative';
                    }
                    
                    // Check if min is less than max (if max has a value)
                    if (maxController.text.isNotEmpty) {
                      final double? maxValue = double.tryParse(maxController.text);
                      if (maxValue != null && double.parse(value) > maxValue) {
                        return 'Min must be ≤ Max';
                      }
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
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
                  errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  helperText: ' ', // Adds space for error message
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    // Check if input is a valid number
                    if (double.tryParse(value) == null) {
                      return 'Enter a valid number';
                    }
                    
                    // Check if input is non-negative
                    if (double.parse(value) < 0) {
                      return 'Must be non-negative';
                    }
                    
                    // Check if max is greater than min (if min has a value)
                    if (minController.text.isNotEmpty) {
                      final double? minValue = double.tryParse(minController.text);
                      if (minValue != null && double.parse(value) < minValue) {
                        return 'Max must be ≥ Min';
                      }
                    }
                  }
                  return null;
                },
              ),
            ],
          );
        } else {
          // Em telas maiores, mantenha o layout horizontal
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
                    errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    helperText: ' ', // Adds space for error message
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // Check if input is a valid number
                      if (double.tryParse(value) == null) {
                        return 'Enter a valid number';
                      }
                      
                      // Check if input is non-negative
                      if (double.parse(value) < 0) {
                        return 'Must be non-negative';
                      }
                      
                      // Check if min is less than max (if max has a value)
                      if (maxController.text.isNotEmpty) {
                        final double? maxValue = double.tryParse(maxController.text);
                        if (maxValue != null && double.parse(value) > maxValue) {
                          return 'Min must be ≤ Max';
                        }
                      }
                    }
                    return null;
                  },
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
                    errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    helperText: ' ', // Adds space for error message
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty) {
                      // Check if input is a valid number
                      if (double.tryParse(value) == null) {
                        return 'Enter a valid number';
                      }
                      
                      // Check if input is non-negative
                      if (double.parse(value) < 0) {
                        return 'Must be non-negative';
                      }
                      
                      // Check if max is greater than min (if min has a value)
                      if (minController.text.isNotEmpty) {
                        final double? minValue = double.tryParse(minController.text);
                        if (minValue != null && double.parse(value) < minValue) {
                          return 'Max must be ≥ Min';
                        }
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildDateRangeFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Em telas muito pequenas, empilhe os campos verticalmente
        if (constraints.maxWidth < 400) {
          return Column(
            children: [
              TextFormField(
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
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                  errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  helperText: ' ', // Adds space for error message
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && _endDateController.text.isNotEmpty) {
                    // Check if start date is before end date
                    final startDate = DateTime.tryParse(value);
                    final endDate = DateTime.tryParse(_endDateController.text);
                    
                    if (startDate != null && endDate != null) {
                      if (startDate.isAfter(endDate)) {
                        return 'Start date must be before end date';
                      }
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
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
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                  errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  helperText: ' ', // Adds space for error message
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && _startDateController.text.isNotEmpty) {
                    // Check if end date is after start date
                    final endDate = DateTime.tryParse(value);
                    final startDate = DateTime.tryParse(_startDateController.text);
                    
                    if (startDate != null && endDate != null) {
                      if (endDate.isBefore(startDate)) {
                        return 'End date must be after start date';
                      }
                    }
                  }
                  return null;
                },
              ),
            ],
          );
        } else {
          // Em telas maiores, mantenha o layout horizontal
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
                    errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    helperText: ' ', // Adds space for error message
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && _endDateController.text.isNotEmpty) {
                      // Check if start date is before end date
                      final startDate = DateTime.tryParse(value);
                      final endDate = DateTime.tryParse(_endDateController.text);
                      
                      if (startDate != null && endDate != null) {
                        if (startDate.isAfter(endDate)) {
                          return 'Start date must be before end date';
                        }
                      }
                    }
                    return null;
                  },
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
                    errorStyle: TextStyle(color: Colors.red[700], fontSize: 12),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    helperText: ' ', // Adds space for error message
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && _startDateController.text.isNotEmpty) {
                      // Check if end date is after start date
                      final endDate = DateTime.tryParse(value);
                      final startDate = DateTime.tryParse(_startDateController.text);
                      
                      if (startDate != null && endDate != null) {
                        if (endDate.isBefore(startDate)) {
                          return 'End date must be after start date';
                        }
                      }
                    }
                    return null;
                  },
                ),
              ),
            ],
          );
        }
      },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use vertical layout on smaller screens to prevent overflow
        bool useVerticalLayout = constraints.maxWidth < 600;
        
        if (useVerticalLayout) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Minimum section
              Text(
                'Minimum',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildRangeInputRow(minController, minUnit, onMinUnitChanged, 'Min', maxController, maxUnit),
              const SizedBox(height: 16),
              
              // Maximum section
              Text(
                'Maximum',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildRangeInputRow(maxController, maxUnit, onMaxUnitChanged, 'Max', minController, minUnit),
            ],
          );
        } else {
          // Use horizontal layout on larger screens
          return Column(
            children: [
              // Header row with labels
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Minimum',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        'Maximum',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Input fields row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Minimum value and unit
                  Expanded(
                    child: _buildRangeInputRow(minController, minUnit, onMinUnitChanged, 'Min', maxController, maxUnit),
                  ),
                  const SizedBox(width: 16),
                  // Maximum value and unit
                  Expanded(
                    child: _buildRangeInputRow(maxController, maxUnit, onMaxUnitChanged, 'Max', minController, minUnit),
                  ),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildRangeInputRow(
    TextEditingController controller,
    String unit,
    void Function(String?) onUnitChanged,
    String validationType,
    TextEditingController otherController,
    String otherUnit,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Value field
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              labelText: 'Value',
              labelStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              errorStyle: TextStyle(color: Colors.red[700], fontSize: 10),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              isDense: true,
            ),
            validator: (value) {
              // Skip validation if lifetime is selected or field is empty
              if (unit == 'lifetime' || (value == null || value.isEmpty)) {
                return null;
              }
              
              // Check if input is a valid integer
              if (int.tryParse(value) == null) {
                return 'Valid number required';
              }
              
              // Check if input is positive
              if (int.parse(value) <= 0) {
                return 'Must be positive';
              }
              
              // Check min/max relationship
              if (otherController.text.isNotEmpty && otherUnit != 'lifetime') {
                final int? otherValue = int.tryParse(otherController.text);
                if (otherValue != null) {
                  // Convert both values to the same unit for comparison
                  int currentValueInDays = _convertToDays(int.parse(value), unit);
                  int otherValueInDays = _convertToDays(otherValue, otherUnit);
                  
                  if (validationType == 'Min' && currentValueInDays > otherValueInDays) {
                    return 'Min > Max';
                  } else if (validationType == 'Max' && currentValueInDays < otherValueInDays) {
                    return 'Max < Min';
                  }
                }
              }
              return null;
            },
          ),
        ),
        const SizedBox(width: 8),
        // Unit dropdown
        Expanded(
          flex: 2,
          child: _buildUnitDropdown(unit, onUnitChanged),
        ),
      ],
    );
  }

  // Callback methods for updating state outside of build
  void _updateSelectedCategories(String category, bool selected) {
    setState(() {
      if (selected) {
        _selectedCategories.add(category);
      } else {
        _selectedCategories.remove(category);
      }
    });
  }

  void _updateSelectedStores(String store, bool selected) {
    setState(() {
      if (selected) {
        _selectedStores.add(store);
      } else {
        _selectedStores.remove(store);
      }
    });
  }

  void _updateSelectedBrands(String brand, bool selected) {
    setState(() {
      if (selected) {
        _selectedBrands.add(brand);
      } else {
        _selectedBrands.remove(brand);
      }
    });
  }

  void _updateMinWarrantyPeriodUnit(String? value) {
    setState(() {
      _minWarrantyPeriodUnit = value ?? 'days';
    });
  }

  void _updateMaxWarrantyPeriodUnit(String? value) {
    setState(() {
      _maxWarrantyPeriodUnit = value ?? 'days';
    });
  }

  void _updateMinWarrantyExtensionUnit(String? value) {
    setState(() {
      _minWarrantyExtensionUnit = value ?? 'days';
    });
  }

  void _updateMaxWarrantyExtensionUnit(String? value) {
    setState(() {
      _maxWarrantyExtensionUnit = value ?? 'days';
    });
  }

  void _updateSortDirection(bool isAscending) {
    setState(() {
      _sortAscending = isAscending;
    });
  }

  // Helper method to convert warranty periods to days for comparison
  int _convertToDays(int value, String unit) {
    switch (unit) {
      case 'days':
        return value;
      case 'months':
        return value * 30; // Approximate months to days
      case 'years':
        return value * 365; // Approximate years to days
      case 'lifetime':
        return 36500; // 100 years as lifetime
      default:
        return value;
    }
  }
  Widget _buildUnitDropdown(String value, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      items: _timeUnits.map((unit) {
        return DropdownMenuItem(
          value: unit,
          child: Text(
            unit.substring(0, 1).toUpperCase() + unit.substring(1),
            style: TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
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
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
      ),
      style: TextStyle(fontSize: 12, color: Colors.black87),
      onChanged: onChanged,
      isExpanded: true, // Prevents overflow by expanding to available width
    );
  }

  Widget _buildSortDirectionButton(bool isAscending, IconData icon, String label, {required bool isLeft}) {
    final isSelected = _sortAscending == isAscending;
    return InkWell(
      onTap: () => _updateSortDirection(isAscending),
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
