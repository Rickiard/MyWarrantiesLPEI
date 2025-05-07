import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FilterPage extends StatefulWidget {
  final Function(Map<String, String>) onApplyFilters;

  const FilterPage({Key? key, required this.onApplyFilters}) : super(key: key);

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _purchaseDateController = TextEditingController();
  final _warrantyPeriodController = TextEditingController();
  final _storeDetailsController = TextEditingController();
  final _brandController = TextEditingController();
  final _warrantyExtensionController = TextEditingController();

  List<String> _categories = [];
  List<String> _brands = [];
  List<String> _stores = [];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _purchaseDateController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _applyFilters() {
    if (_formKey.currentState!.validate()) {
      final filters = {
        'name': _nameController.text,
        'category': _categoryController.text,
        'price': _priceController.text,
        'purchaseDate': _purchaseDateController.text,
        'warrantyPeriod': _warrantyPeriodController.text,
        'storeDetails': _storeDetailsController.text,
        'brand': _brandController.text,
        'warrantyExtension': _warrantyExtensionController.text,
      };
      widget.onApplyFilters(filters);
      Navigator.pop(context); // Close the filter page after applying filters
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _purchaseDateController.dispose();
    _warrantyPeriodController.dispose();
    _storeDetailsController.dispose();
    _brandController.dispose();
    _warrantyExtensionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAFE1F0),
      appBar: AppBar(
        title: Text('Filter Products'),
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
              Text(
                'Search by:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              
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
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _categoryController.text.isNotEmpty ? _categoryController.text : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: _categories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryController.text = value ?? '';
                  });
                },
              ),
              SizedBox(height: 16),

              // Product Price
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Product Price',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16),

              // Purchase Date
              TextFormField(
                controller: _purchaseDateController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Purchase Date',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(context),
                  ),
                ),
                readOnly: true,
              ),
              SizedBox(height: 16),

              // Warranty Period
              DropdownButtonFormField<String>(
                value: _warrantyPeriodController.text.isNotEmpty ? _warrantyPeriodController.text : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Warranty Period',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: [
                  '6 months',
                  '1 year',
                  '2 years',
                  '3 years',
                  '5 years',
                  'Lifetime',
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _warrantyPeriodController.text = value ?? '';
                  });
                },
              ),
              SizedBox(height: 16),

              // Store Dropdown
              DropdownButtonFormField<String>(
                value: _storeDetailsController.text.isNotEmpty ? _storeDetailsController.text : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Store',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: _stores.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _storeDetailsController.text = value ?? '';
                  });
                },
              ),
              SizedBox(height: 16),

              // Brand Dropdown
              DropdownButtonFormField<String>(
                value: _brandController.text.isNotEmpty ? _brandController.text : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Brand',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: _brands.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _brandController.text = value ?? '';
                  });
                },
              ),
              SizedBox(height: 16),

              // Warranty Extension
              DropdownButtonFormField<String>(
                value: _warrantyExtensionController.text.isNotEmpty ? _warrantyExtensionController.text : null,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Warranty Extension',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                items: [
                  '6 months',
                  '1 year',
                  '2 years',
                  '3 years',
                  '5 years',
                ].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _warrantyExtensionController.text = value ?? '';
                  });
                },
              ),
              SizedBox(height: 16),

              // Apply and Clear Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Clear all filters
                        setState(() {
                          _nameController.clear();
                          _categoryController.clear();
                          _priceController.clear();
                          _purchaseDateController.clear();
                          _warrantyPeriodController.clear();
                          _storeDetailsController.clear();
                          _brandController.clear();
                          _warrantyExtensionController.clear();
                        });
                      },
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
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final filters = {
                            'name': _nameController.text,
                            'category': _categoryController.text,
                            'price': _priceController.text,
                            'purchaseDate': _purchaseDateController.text,
                            'warrantyPeriod': _warrantyPeriodController.text,
                            'storeDetails': _storeDetailsController.text,
                            'brand': _brandController.text,
                            'warrantyExtension': _warrantyExtensionController.text,
                          };
                          widget.onApplyFilters(filters);
                        }
                      },
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
