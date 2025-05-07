import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

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
  final _warrantyPeriodController = TextEditingController();
  final _storeDetailsController = TextEditingController();
  final _brandController = TextEditingController();
  final _notesController = TextEditingController();
  final _warrantyExtensionController = TextEditingController();
  
  File? _productImage;
  File? _receiptFile;
  File? _warrantyFile;
  File? _otherDocuments;
  bool _isLoading = false;
  bool _isWarrantyExtensionActivated = false;

  List<String> _categories = [];
  List<String> _brands = [];
  List<String> _stores = [];
  List<String> _warrantyPeriods = [
    '6 months',
    '1 year',
    '2 years',
    '3 years',
    '5 years',
    'Lifetime',
  ];
  List<String> _warrantyExtensions = [
    '6 months',
    '1 year',
    '2 years',
    '3 years',
    '5 years',
  ];

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
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _productImage = File(image.path);
      });
    }
  }

  Future<void> _pickFile(void Function(File) onFilePicked) async {
    // TODO: Implement file picking functionality
    // This would require adding a file picker package
  }

  Future<String?> _uploadFile(File file, String path) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(path);
      final uploadTask = ref.putFile(file);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error uploading file: $e');
      return null;
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload files
      String? imageUrl;
      String? receiptUrl;
      String? warrantyUrl;
      String? otherDocsUrl;

      if (_productImage != null) {
        imageUrl = await _uploadFile(_productImage!, 'products/${user.uid}/${DateTime.now()}_image.jpg');
      }
      if (_receiptFile != null) {
        receiptUrl = await _uploadFile(_receiptFile!, 'receipts/${user.uid}/${DateTime.now()}_receipt.pdf');
      }
      if (_warrantyFile != null) {
        warrantyUrl = await _uploadFile(_warrantyFile!, 'warranties/${user.uid}/${DateTime.now()}_warranty.pdf');
      }
      if (_otherDocuments != null) {
        otherDocsUrl = await _uploadFile(_otherDocuments!, 'documents/${user.uid}/${DateTime.now()}_other.pdf');
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
        'warrantyPeriod': _warrantyPeriodController.text,
        'storeDetails': _storeDetailsController.text,
        'brand': _brandController.text,
        'notes': _notesController.text,
        'warrantyExtension': _isWarrantyExtensionActivated ? _warrantyExtensionController.text : null,
        'imageUrl': imageUrl,
        'receiptUrl': receiptUrl,
        'warrantyUrl': warrantyUrl,
        'otherDocumentsUrl': otherDocsUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      Navigator.pop(context, true);
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

              _buildDropdownWithAddOption('Warranty Period', _warrantyPeriods, _warrantyPeriodController),
              SizedBox(height: 16),

              SwitchListTile(
                title: Text('Activate Warranty Extension'),
                value: _isWarrantyExtensionActivated,
                onChanged: (bool value) {
                  setState(() {
                    _isWarrantyExtensionActivated = value;
                    if (!value) {
                      _warrantyExtensionController.text = '';
                    }
                  });
                },
              ),
              if (_isWarrantyExtensionActivated)
                _buildDropdownWithAddOption('Warranty Extension', _warrantyExtensions, _warrantyExtensionController),
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
                    onPressed: () => _pickFile((file) => setState(() => _receiptFile = file)),
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
                    onPressed: () => _pickFile((file) => setState(() => _warrantyFile = file)),
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
                    onPressed: () => _pickFile((file) => setState(() => _otherDocuments = file)),
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
    _warrantyPeriodController.dispose();
    _storeDetailsController.dispose();
    _brandController.dispose();
    _notesController.dispose();
    _warrantyExtensionController.dispose();
    super.dispose();
  }
}
