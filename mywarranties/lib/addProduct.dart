import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
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

  // File names for display
  String? _receiptFileName;
  String? _warrantyFileName;
  String? _otherDocsFileName;

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
    if (picked != null) {      controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
    }
  }
  Future<void> _showImageSourceDialog() async {
    final ImageSource? source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Image Source'),
          content: Text('Choose how you want to add the image:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.camera),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Camera'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(ImageSource.gallery),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library),
                  SizedBox(width: 8),
                  Text('Gallery'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
    if (source != null) {
      await _pickImage(source);
    }
  }
  Future<void> _pickImage([ImageSource? source]) async {
    if (source != null) {
      // Direct camera/gallery access
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        setState(() {
          _productImage = File(image.path);
          _productImagePath = image.path;
          _productImageUrl = ''; // Empty string as we're not using Firebase Storage
        });
        
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product image uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      // Fallback to file storage service for backward compatibility
      final result = await _fileStorage.pickAndStoreImage(context: context);
      
      if (result != null) {
        setState(() {
          _productImage = File(result['localPath']!);
          _productImagePath = result['localPath'];
          _productImageUrl = ''; // Empty string as we're not using Firebase Storage
        });
        
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product image uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
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
            children: [              // Add Photo
              GestureDetector(
                onTap: () => _showImageSourceDialog(),                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: 200,   // Significantly increased for better horizontal image display
                    maxHeight: 300,  // Increased height for better vertical image display
                    minWidth: 120,   // Increased minimum for better visibility
                    minHeight: 80,   // Increased minimum height
                  ),
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _productImage != null ? Colors.green : Colors.grey.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _productImage != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _productImage!, 
                                fit: BoxFit.contain, // Changed to contain to avoid cropping
                                width: double.infinity, 
                                height: double.infinity
                              ),
                            ),
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(Icons.check, color: Colors.white, size: 18),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Tap to change image',
                                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 48, color: Colors.grey.shade600),
                            SizedBox(height: 12),
                            Text(
                              'Add Product Photo', 
                              style: TextStyle(
                                color: Colors.grey.shade700, 
                                fontWeight: FontWeight.w600,
                                fontSize: 16
                              )
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Tap to upload from camera or gallery', 
                              style: TextStyle(
                                color: Colors.grey.shade500, 
                                fontSize: 12
                              )
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 20),

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
              SizedBox(height: 16),              // Receipt Upload
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _receiptPath != null ? Colors.green : Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _receiptPath != null ? Icons.check_circle : Icons.receipt,
                          color: _receiptPath != null ? Colors.green : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Receipt',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _receiptPath != null ? Colors.green.shade700 : Colors.black,
                            ),
                          ),
                        ),                        ElevatedButton(
                          onPressed: () async {
                            _showDocumentSourceDialog('receipts', (result) {
                              if (result != null) {
                                setState(() {
                                  _receiptPath = result['localPath'];
                                  _receiptUrl = result['remoteUrl'];
                                  _receiptFileName = path.basename(result['localPath']!);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Receipt uploaded successfully!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          },
                          child: Text(_receiptPath != null ? 'Change file' : 'Upload file'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _receiptPath != null ? Colors.green.shade50 : Colors.white,
                            foregroundColor: _receiptPath != null ? Colors.green.shade700 : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    if (_receiptFileName != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'File: $_receiptFileName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),              SizedBox(height: 16),

              // Warranty Upload
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _warrantyPath != null ? Colors.green : Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _warrantyPath != null ? Icons.check_circle : Icons.verified_user,
                          color: _warrantyPath != null ? Colors.green : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Warranty',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _warrantyPath != null ? Colors.green.shade700 : Colors.black,
                            ),
                          ),
                        ),                        ElevatedButton(
                          onPressed: () async {
                            _showDocumentSourceDialog('warranties', (result) {
                              if (result != null) {
                                setState(() {
                                  _warrantyPath = result['localPath'];
                                  _warrantyUrl = result['remoteUrl'];
                                  _warrantyFileName = path.basename(result['localPath']!);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Warranty document uploaded successfully!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          },
                          child: Text(_warrantyPath != null ? 'Change file' : 'Upload file'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _warrantyPath != null ? Colors.green.shade50 : Colors.white,
                            foregroundColor: _warrantyPath != null ? Colors.green.shade700 : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    if (_warrantyFileName != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'File: $_warrantyFileName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),              SizedBox(height: 16),

              // Other Documents Upload
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _otherDocsPath != null ? Colors.green : Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _otherDocsPath != null ? Icons.check_circle : Icons.description,
                          color: _otherDocsPath != null ? Colors.green : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Other Documents',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _otherDocsPath != null ? Colors.green.shade700 : Colors.black,
                            ),
                          ),
                        ),                        ElevatedButton(
                          onPressed: () async {
                            _showDocumentSourceDialog('documents', (result) {
                              if (result != null) {
                                setState(() {
                                  _otherDocsPath = result['localPath'];
                                  _otherDocsUrl = result['remoteUrl'];
                                  _otherDocsFileName = path.basename(result['localPath']!);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Document uploaded successfully!'),
                                    backgroundColor: Colors.green,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            });
                          },
                          child: Text(_otherDocsPath != null ? 'Change file' : 'Upload file'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _otherDocsPath != null ? Colors.green.shade50 : Colors.white,
                            foregroundColor: _otherDocsPath != null ? Colors.green.shade700 : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    if (_otherDocsFileName != null) ...[
                      SizedBox(height: 8),
                      Text(
                        'File: $_otherDocsFileName',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
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
  Future<void> _showDocumentSourceDialog(String folder, Function(Map<String, String>?) onResult) async {
    final source = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Document Source'),
          content: Text('Choose how you want to add the document:'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('camera'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Camera'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('gallery'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library),
                  SizedBox(width: 8),
                  Text('Gallery'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop('files'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insert_drive_file),
                  SizedBox(width: 8),
                  Text('Files'),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
    
    if (source != null) {
      Map<String, String>? result;
      if (source == 'camera' || source == 'gallery') {
        result = await _pickImageAsDocument(folder, source == 'camera' ? ImageSource.camera : ImageSource.gallery);
      } else if (source == 'files') {
        result = await _pickAndUploadDocument(folder);
      }
      onResult(result);
    }
  }

  Future<Map<String, String>?> _pickImageAsDocument(String folder, ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    
    if (image != null) {
      try {
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String localDirPath = '${appDir.path}/$folder';
        
        final Directory localDir = Directory(localDirPath);
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
        
        final String fileName = '${const Uuid().v4()}${path.extension(image.path)}';
        final String localPath = '$localDirPath/$fileName';
        
        final File localFile = File(localPath);
        await localFile.writeAsBytes(await image.readAsBytes());
        
        return {
          'localPath': localPath,
          'remoteUrl': '',
        };
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving image: $e'), backgroundColor: Colors.red),
        );
      }
    }
    return null;
  }
}
