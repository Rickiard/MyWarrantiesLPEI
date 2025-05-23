import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'list.dart';
import 'services/local_file_storage_service.dart';

class AddProductPage extends StatefulWidget {
  @override
  _AddProductPageState createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _priceController = TextEditingController();
  final _purchaseDateController = TextEditingController();
  final _warrantyValueController = TextEditingController();
  final _warrantyUnitController = TextEditingController();
  final _warrantyExtensionValueController = TextEditingController();
  final _warrantyExtensionUnitController = TextEditingController();
  final _storeDetailsController = TextEditingController();
  final _brandController = TextEditingController();
  final _notesController = TextEditingController();

  File? _productImage;
  bool _isLoading = false;
  bool _isWarrantyExtensionActivated = false;

  List<String> _categories = [];
  List<String> _brands = [];
  List<String> _stores = [];
  final List<String> _timeUnits = ['days', 'months', 'years', 'lifetime'];
  String _selectedWarrantyUnit = 'days';
  String _selectedExtensionUnit = 'days';

  // Storage service
  final FileStorageService _fileStorage = FileStorageService();

  // File paths and URLs
  String? _productImagePath;
  String? _receiptPath;
  String? _warrantyPath;
  String? _otherDocsPath;
  
  // Remote URLs dos documentos
  String? _productImageUrl;
  String? _receiptUrl;
  String? _warrantyUrl;
  String? _otherDocsUrl;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
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

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }
  Future<void> _pickImage() async {
    final result = await _fileStorage.pickAndStoreImage(context: context);
    
    if (result != null) {
      setState(() {
        _productImage = File(result['localPath']!);
        _productImagePath = result['localPath'];
        _productImageUrl = ''; // Empty string as we're not using Firebase Storage
      });
    }
  }

  Future<Map<String, String>?> _pickAndUploadDocument(String folder) async {
    final result = await _fileStorage.pickAndStoreDocument(
      context: context,
      folder: folder,
    );
    
    return result;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');      // We'll use the uploaded image URL directly

      // Format warranty period
      String warrantyPeriod;
      if (_selectedWarrantyUnit == 'lifetime') {
        warrantyPeriod = 'Lifetime';
      } else {
        warrantyPeriod = '${_warrantyValueController.text} ${_selectedWarrantyUnit}';
      }

      // Format warranty extension
      String? warrantyExtension;
      if (_isWarrantyExtensionActivated && _warrantyExtensionValueController.text.isNotEmpty) {
        warrantyExtension = '${_warrantyExtensionValueController.text} ${_selectedExtensionUnit}';
      }

      // Add to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .add({
        'name': _nameController.text,
        'category': _categoryController.text,
        'price': _priceController.text,
        'purchaseDate': _purchaseDateController.text,
        'warrantyPeriod': warrantyPeriod,
        'warrantyUnit': _selectedWarrantyUnit,
        'warrantyExtension': warrantyExtension,
        'warrantyExtensionUnit': _isWarrantyExtensionActivated ? _selectedExtensionUnit : null,
        'storeDetails': _storeDetailsController.text,
        'brand': _brandController.text,
        'notes': _notesController.text,
        // URLs for remote access
        'imageUrl': _productImageUrl,
        'receiptUrl': _receiptUrl,
        'warrantyUrl': _warrantyUrl,
        'otherDocumentsUrl': _otherDocsUrl,
        // Local paths for offline access
        'imagePath': _productImagePath,
        'receiptPath': _receiptPath,
        'warrantyPath': _warrantyPath,
        'otherDocumentsPath': _otherDocsPath,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Navigate to list page and remove all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => ListPage()),
        (route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding product: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildDropdownWithAddOption(String label, List<String> options, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: controller.text.isNotEmpty ? controller.text : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          items: options.map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              controller.text = value ?? '';
            });
          },
        ),
        TextButton(
          onPressed: () async {
            final newValue = await showDialog<String>(
              context: context,
              builder: (BuildContext context) {
                final TextEditingController newController = TextEditingController();
                return AlertDialog(
                  title: Text('Add New $label'),
                  content: TextField(
                    controller: newController,
                    decoration: InputDecoration(hintText: 'Enter new $label'),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, newController.text),
                      child: Text('Add'),
                    ),
                  ],
                );
              },
            );

            if (newValue != null && newValue.isNotEmpty) {
              setState(() {
                options.add(newValue);
                controller.text = newValue;
              });
            }
          },
          child: Text('Add New $label'),
        ),
      ],
    );
  }

  Widget _buildWarrantyPeriodInput(String label, TextEditingController valueController, String unit, Function(String?) onUnitChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: valueController,
                enabled: unit != 'lifetime',
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Value',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (unit != 'lifetime') {
                    if (v == null || v.isEmpty) return 'Required';
                    final num = int.tryParse(v);
                    if (num == null || num <= 0) return 'Invalid value';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: unit,
                items: _timeUnits.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(unit.substring(0, 1).toUpperCase() + unit.substring(1)),
                  );
                }).toList(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onChanged: (newUnit) {
                  if (newUnit == 'lifetime') {
                    valueController.clear();
                  }
                  onUnitChanged(newUnit);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAFE1F0),
      appBar: AppBar(
        title: Text('Product Registration'),
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
              // Add Photo
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _productImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_productImage!, fit: BoxFit.cover),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload, size: 40, color: Colors.grey),
                            Text('Add Photo', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 16),

              // Text Fields
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: 16),

              _buildDropdownWithAddOption('Category', _categories, _categoryController),
              SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Price',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final price = double.tryParse(v);
                  if (price == null || price <= 0) return 'Enter a valid price';
                  return null;
                },
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _purchaseDateController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Purchase Date',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.calendar_today),
                    onPressed: () => _selectDate(_purchaseDateController),
                  ),
                ),
                readOnly: true,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              SizedBox(height: 16),

              _buildWarrantyPeriodInput(
                'Warranty Period', 
                _warrantyValueController,
                _selectedWarrantyUnit,
                (unit) => setState(() => _selectedWarrantyUnit = unit ?? 'days'),
              ),
              SizedBox(height: 16),

              SwitchListTile(
                title: Text('Activate Warranty Extension'),
                value: _isWarrantyExtensionActivated,
                onChanged: (bool value) {
                  setState(() {
                    _isWarrantyExtensionActivated = value;
                    if (!value) {
                      _warrantyExtensionValueController.clear();
                      _selectedExtensionUnit = 'days';
                    }
                  });
                },
              ),
              if (_isWarrantyExtensionActivated)
                _buildWarrantyPeriodInput(
                  'Warranty Extension',
                  _warrantyExtensionValueController,
                  _selectedExtensionUnit,
                  (unit) => setState(() => _selectedExtensionUnit = unit ?? 'days'),
                ),
              SizedBox(height: 16),

              _buildDropdownWithAddOption('Store Details', _stores, _storeDetailsController),
              SizedBox(height: 16),

              _buildDropdownWithAddOption('Product Brand', _brands, _brandController),
              SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Other Notes',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),

              // Upload Documents Section
              Text('Upload Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),

              // Receipt Upload
              Row(
                children: [
                  Expanded(child: Text('Receipt')),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await _pickAndUploadDocument('receipts');
                      if (result != null) {
                        setState(() {
                          _receiptPath = result['localPath'];
                          _receiptUrl = result['remoteUrl'];
                        });
                      }
                    },
                    child: Text('Upload file'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Warranty Upload
              Row(
                children: [
                  Expanded(child: Text('Warranty')),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await _pickAndUploadDocument('warranties');
                      if (result != null) {
                        setState(() {
                          _warrantyPath = result['localPath'];
                          _warrantyUrl = result['remoteUrl'];
                        });
                      }
                    },
                    child: Text('Upload file'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Other Documents Upload
              Row(
                children: [
                  Expanded(child: Text('Other Documents')),
                  ElevatedButton(
                    onPressed: () async {
                      final result = await _pickAndUploadDocument('documents');
                      if (result != null) {
                        setState(() {
                          _otherDocsPath = result['localPath'];
                          _otherDocsUrl = result['remoteUrl'];
                        });
                      }
                    },
                    child: Text('Upload file'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Add Button
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('ADD', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _purchaseDateController.dispose();
    _warrantyValueController.dispose();
    _warrantyUnitController.dispose();
    _warrantyExtensionValueController.dispose();
    _warrantyExtensionUnitController.dispose();
    _storeDetailsController.dispose();
    _brandController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
