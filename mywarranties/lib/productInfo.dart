import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'services/local_file_storage_service.dart';
import 'services/image_copy_service.dart';
import 'services/file_copy_service.dart';

class ProductInfoPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onDelete;

  const ProductInfoPage({Key? key, required this.product, this.onDelete}) : super(key: key);

  @override
  State<ProductInfoPage> createState() => _ProductInfoPageState();
}

class _ProductInfoPageState extends State<ProductInfoPage> {
  bool _isLoading = false;
  bool _isEditing = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isWarrantyExtensionActivated = false;
  List<String> _categories = [];
  List<String> _brands = [];
  List<String> _stores = [];
  final _warrantyUnitController = TextEditingController();
  final _warrantyExtensionUnitController = TextEditingController();  final List<String> _timeUnits = ['days', 'months', 'years', 'lifetime'];
  final FileStorageService _fileStorage = FileStorageService();
  final ImageCopyService _imageCopyService = ImageCopyService();
  final FileCopyService _fileCopyService = FileCopyService();

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _warrantyUnitController.dispose();
    _warrantyExtensionUnitController.dispose();
    super.dispose();
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
  Future<void> _deleteProduct() async {

    if (widget.onDelete != null) {
      widget.onDelete!();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .doc(widget.product['id'])
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Product deleted successfully')),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Unable to delete product. Please try again later.')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 3),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _launchUrl(String? url, {String? localPath}) async {
    if ((url == null || url.isEmpty) && (localPath == null || localPath.isEmpty)) return;

    // Try to open the local file first if available
    if (localPath != null && localPath.isNotEmpty) {
      final localFile = File(localPath);
      if (await localFile.exists()) {
        try {
          // Use the file_storage_service to open the local file
          await _fileStorage.openFile(context, localPath);
          return;
        } catch (e) {
          print('Error opening local file: $e');
          // Fall back to remote URL if local file can't be opened
        }
      }
    }

    // Fall back to remote URL
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Could not open the file. Please check if it exists.')),
                  ],
                ),
                backgroundColor: Colors.blue[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(child: Text('Unable to open the file. The file may be corrupted or inaccessible.')),
                ],
              ),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('No file available to open.')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }  }

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
  }  Future<void> _pickImage([ImageSource? source]) async {
    if (source != null) {
      // Direct camera/gallery access
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      
      if (image != null) {
        // ✅ NOVA ABORDAGEM: Criar cópia independente em vez de usar caminho original
        final String? copiedImagePath = await _imageCopyService.createImageCopy(image.path);
        
        if (copiedImagePath != null) {
          setState(() {
            widget.product['imageUrl'] = ''; // Empty string as we're not using Firebase Storage
            widget.product['imagePath'] = copiedImagePath; // Usar caminho da cópia
          });
          
          // Update in Firestore
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('products')
                .doc(widget.product['id'])
                .update({
              'imageUrl': '', // Empty string as we're not using Firebase Storage
              'imagePath': copiedImagePath, // Guardar caminho da cópia
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(                children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Photo added successfully!')),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          // Fallback para caminho original se a cópia falhar
          setState(() {
            widget.product['imageUrl'] = '';
            widget.product['imagePath'] = image.path;
          });
          
          // Update in Firestore with original path
          final user = _auth.currentUser;
          if (user != null) {
            await _firestore
                .collection('users')
                .doc(user.uid)
                .collection('products')
                .doc(widget.product['id'])
                .update({
              'imageUrl': '',
              'imagePath': image.path,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(                content: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Photo saved with original reference')),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } else {
      // Fallback to file storage service for backward compatibility
      final result = await _fileStorage.pickAndStoreImage(context: context);
      
      if (result != null) {
        setState(() {
          widget.product['imageUrl'] = ''; // Empty string as we're not using Firebase Storage
          widget.product['imagePath'] = result['localPath'];
        });
        
        // Update in Firestore
        final user = _auth.currentUser;
        if (user != null) {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('products')
              .doc(widget.product['id'])
              .update({
            'imageUrl': '', // Empty string as we're not using Firebase Storage
            'imagePath': result['localPath'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }

  Future<void> _selectDate(Map<String, dynamic> product, String key) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        product[key] = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }
  Future<void> _pickAndUploadDocument(String field) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    // Determine the folder name based on the field
    String folderName = 'documents';
    if (field == 'receiptUrl') folderName = 'receipts';
    if (field == 'warrantyUrl') folderName = 'warranties';
    
    // First, use the original service to pick the file
    final result = await _fileStorage.pickAndStoreDocument(context: context, folder: folderName);
    
    if (result != null && result['localPath'] != null) {
      // ✅ NEW LOGIC: Create independent copy of the document
      final String? copiedFilePath = await _fileCopyService.createFileCopy(
        result['localPath']!,
        folderName, // 'receipts', 'warranties', 'documents'
      );
      
      if (copiedFilePath != null) {
        // Success - use independent copy
        String pathField = field.replaceAll('Url', 'Path'); // receiptUrl -> receiptPath
        
        setState(() {
          widget.product[field] = ''; // Empty string as we're not using Firebase Storage
          widget.product[pathField] = copiedFilePath; // Use copy path
        });
        
        // Update in Firestore
        try {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('products')
              .doc(widget.product['id'])
              .update({
            field: '', // Empty string as we're not using Firebase Storage
            pathField: copiedFilePath, // Save copy path
            'updatedAt': FieldValue.serverTimestamp(),
          });
            if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Document added successfully!')),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Error updating document in database.')),
                  ],
                ),
                backgroundColor: Colors.red[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } else {
        // Fallback - use original file with warning
        String pathField = field.replaceAll('Url', 'Path');
        
        setState(() {
          widget.product[field] = ''; // Empty string as we're not using Firebase Storage
          widget.product[pathField] = result['localPath'];
        });
        
        // Update in Firestore
        try {
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('products')
              .doc(widget.product['id'])
              .update({
            field: '', // Empty string as we're not using Firebase Storage
            pathField: result['localPath'],
            'updatedAt': FieldValue.serverTimestamp(),
          });
            if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Document saved with original reference')),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 10),
                    Expanded(child: Text('Error updating document in database.')),
                  ],
                ),
                backgroundColor: Colors.red[700],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    }
  }

  Widget _buildWarrantyPeriodInput(String label, String valueKey, String unitKey, bool isEnabled) {
    final existingPeriod = widget.product[valueKey]?.toString() ?? '';
    final isLifetime = existingPeriod.toLowerCase() == 'lifetime';
    int? value;
    String unit = 'days';

    if (!isLifetime && existingPeriod.isNotEmpty) {
      final parts = existingPeriod.toLowerCase().split(' ');
      if (parts.length >= 2) {
        value = int.tryParse(parts[0]);
        if (parts[1].startsWith('year')) unit = 'years';
        else if (parts[1].startsWith('month')) unit = 'months';
        else if (parts[1].startsWith('day')) unit = 'days';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: isLifetime ? null : value?.toString(),
                enabled: isEnabled && !isLifetime,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Value',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) {
                  if (!isLifetime) {
                    if (v == null || v.isEmpty) return 'Required';
                    final num = int.tryParse(v);
                    if (num == null || num <= 0) return 'Invalid value';
                  }
                  return null;
                },
                onChanged: (value) {
                  final unit = widget.product[unitKey] ?? 'days';
                  if (value.isNotEmpty) {
                    widget.product[valueKey] = '$value $unit';
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: isLifetime ? 'lifetime' : unit,
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
                onChanged: isEnabled ? (newUnit) {
                  setState(() {
                    if (newUnit == 'lifetime') {
                      widget.product[valueKey] = 'Lifetime';
                    } else {
                      final value = widget.product[valueKey]?.toString().split(' ')[0] ?? '0';
                      widget.product[valueKey] = '$value $newUnit';
                    }
                    widget.product[unitKey] = newUnit;
                  });
                } : null,
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
      backgroundColor: const Color(0xFFAFE1F0),      appBar: AppBar(
        title: const Text('Product Information'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isEditing
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  // Cancel editing and go back
                  setState(() {
                    _isEditing = false;
                  });
                  Navigator.pop(context);
                },
              )
            : null, // Use default back button when not editing
        actions: [
          if (_isEditing)
            IconButton(
              icon: Icon(Icons.close),
              onPressed: () {
                // Cancel editing without saving
                setState(() {
                  _isEditing = false;
                });
              },
            ),
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveProduct().then((_) {
                  setState(() {
                    _isEditing = false;
                  });
                  Navigator.pop(context, true);
                });
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [              GestureDetector(
                onTap: _isEditing ? _showImageSourceDialog : null,
                child: Container(
                  width: double.infinity,
                  height: 300,
                  margin: EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: _isEditing 
                        ? Border.all(color: Colors.blue, width: 2)
                        : Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [                      widget.product['imagePath'] != null && widget.product['imagePath'].toString().isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.file(
                                File(widget.product['imagePath']),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(
                                    child: Icon(Icons.image_not_supported, size: 80, color: Colors.grey)
                                  );
                                },
                              ),
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [                                  Icon(
                                    _isEditing ? Icons.add_a_photo : Icons.image_outlined, 
                                    size: 64, 
                                    color: _isEditing ? Colors.blue : Colors.grey.shade600
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    _isEditing ? 'Tap to add photo' : 'No photo available', 
                                    style: TextStyle(
                                      color: _isEditing ? Colors.blue : Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18
                                    )
                                  ),
                                  if (_isEditing) ...[
                                    SizedBox(height: 8),
                                    Text(
                                      'Camera or gallery', 
                                      style: TextStyle(
                                        color: Colors.blue.shade400,
                                        fontSize: 14
                                      )
                                    ),
                                  ],
                                ],
                              ),
                            ),
                      if (_isEditing && widget.product['imagePath'] != null && widget.product['imagePath'].toString().isNotEmpty)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(Icons.edit, color: Colors.white, size: 18),
                          ),
                        ),                      if (_isEditing && widget.product['imagePath'] != null && widget.product['imagePath'].toString().isNotEmpty)
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
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(
                initialValue: widget.product['name'],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                enabled: _isEditing,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
                onChanged: (value) => widget.product['name'] = value,
              ),
              const SizedBox(height: 16),

              _buildDropdownWithAddOption('Category', _categories, widget.product, 'category', _isEditing),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: widget.product['price'],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Price',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.number,
                enabled: _isEditing,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final price = double.tryParse(v);
                  if (price == null || price <= 0) return 'Enter a valid price';
                  return null;
                },
                onChanged: (value) => widget.product['price'] = value,
              ),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: widget.product['purchaseDate'],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Purchase Date',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  suffixIcon: _isEditing
                      ? IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDate(widget.product, 'purchaseDate'),
                        )
                      : null,
                ),
                readOnly: !_isEditing,
                onChanged: (value) => widget.product['purchaseDate'] = value,
              ),
              const SizedBox(height: 16),

              _buildWarrantyPeriodInput('Warranty Period', 'warrantyPeriod', 'warrantyUnit', _isEditing),
              const SizedBox(height: 16),

              SwitchListTile(
                title: const Text('Activate Warranty Extension'),
                value: _isWarrantyExtensionActivated,
                onChanged: _isEditing
                    ? (bool value) {
                        setState(() {
                          _isWarrantyExtensionActivated = value;
                          if (!value) {
                            widget.product['warrantyExtension'] = '';
                            widget.product['warrantyExtensionUnit'] = '';
                          }
                        });
                      }
                    : null,
              ),
              if (_isWarrantyExtensionActivated)
                _buildWarrantyPeriodInput('Warranty Extension', 'warrantyExtension', 'warrantyExtensionUnit', _isEditing),
              const SizedBox(height: 16),

              _buildDropdownWithAddOption('Store Details', _stores, widget.product, 'storeDetails', _isEditing),
              const SizedBox(height: 16),

              _buildDropdownWithAddOption('Product Brand', _brands, widget.product, 'brand', _isEditing),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: widget.product['notes'],
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  labelText: 'Other Notes',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 3,
                enabled: _isEditing,
                onChanged: (value) => widget.product['notes'] = value,
              ),
              const SizedBox(height: 24),              const Text('View and Upload Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Receipt Upload Container
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ((widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty) ||
                           (widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty))
                        ? Colors.green 
                        : Colors.grey.shade300
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          ((widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty) ||
                           (widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty))
                              ? Icons.check_circle 
                              : Icons.receipt,
                          color: ((widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty) ||
                                 (widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty))
                              ? Colors.green 
                              : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: ((widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty) ||
                                   (widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty))
                                ? () => _launchUrl(
                                    widget.product['receiptUrl'],
                                    localPath: widget.product['receiptPath'],
                                  )
                                : null,
                            child: Text(
                              'Receipt',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: ((widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty) ||
                                       (widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty))
                                    ? Colors.green.shade700 
                                    : Colors.black,
                                decoration: ((widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty) ||
                                            (widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty))
                                    ? TextDecoration.underline 
                                    : null,
                              ),
                            ),
                          ),
                        ),                        ElevatedButton(
                          onPressed: _isEditing
                              ? () => _showDocumentSourceDialog('receiptUrl', (result) {
                                  if (result != null) {
                                    // UI update is handled in _pickImageAsDocument
                                  }
                                })
                              : null,
                          child: Text(((widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty) ||
                                      (widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty))
                              ? 'Change file' 
                              : 'Upload file'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ((widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty) ||
                                              (widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty))
                                ? Colors.green.shade50 
                                : Colors.white,
                            foregroundColor: ((widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty) ||
                                             (widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty))
                                ? Colors.green.shade700 
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    if ((widget.product['receiptPath'] != null && widget.product['receiptPath'].isNotEmpty)) ...[
                      SizedBox(height: 8),
                      Text(
                        'File: ${widget.product['receiptPath']?.split('/').last ?? 'Receipt document'}',
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
              const SizedBox(height: 16),

              // Warranty Upload Container
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ((widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty) ||
                           (widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty))
                        ? Colors.green 
                        : Colors.grey.shade300
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          ((widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty) ||
                           (widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty))
                              ? Icons.check_circle 
                              : Icons.verified_user,
                          color: ((widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty) ||
                                 (widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty))
                              ? Colors.green 
                              : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: ((widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty) ||
                                   (widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty))
                                ? () => _launchUrl(
                                    widget.product['warrantyUrl'],
                                    localPath: widget.product['warrantyPath'],
                                  )
                                : null,
                            child: Text(
                              'Warranty',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: ((widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty) ||
                                       (widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty))
                                    ? Colors.green.shade700 
                                    : Colors.black,
                                decoration: ((widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty) ||
                                            (widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty))
                                    ? TextDecoration.underline 
                                    : null,
                              ),
                            ),
                          ),
                        ),                        ElevatedButton(
                          onPressed: _isEditing
                              ? () => _showDocumentSourceDialog('warrantyUrl', (result) {
                                  if (result != null) {
                                    // UI update is handled in _pickImageAsDocument
                                  }
                                })
                              : null,
                          child: Text(((widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty) ||
                                      (widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty))
                              ? 'Change file' 
                              : 'Upload file'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ((widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty) ||
                                              (widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty))
                                ? Colors.green.shade50 
                                : Colors.white,
                            foregroundColor: ((widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty) ||
                                             (widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty))
                                ? Colors.green.shade700 
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    if ((widget.product['warrantyPath'] != null && widget.product['warrantyPath'].isNotEmpty)) ...[
                      SizedBox(height: 8),
                      Text(
                        'File: ${widget.product['warrantyPath']?.split('/').last ?? 'Warranty document'}',
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
              const SizedBox(height: 16),

              // Other Documents Upload Container
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: ((widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty) ||
                           (widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty))
                        ? Colors.green 
                        : Colors.grey.shade300
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          ((widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty) ||
                           (widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty))
                              ? Icons.check_circle 
                              : Icons.description,
                          color: ((widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty) ||
                                 (widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty))
                              ? Colors.green 
                              : Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: ((widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty) ||
                                   (widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty))
                                ? () => _launchUrl(
                                    widget.product['otherDocumentsUrl'],
                                    localPath: widget.product['otherDocumentsPath'],
                                  )
                                : null,
                            child: Text(
                              'Other Documents',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: ((widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty) ||
                                       (widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty))
                                    ? Colors.green.shade700 
                                    : Colors.black,
                                decoration: ((widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty) ||
                                            (widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty))
                                    ? TextDecoration.underline 
                                    : null,
                              ),
                            ),
                          ),
                        ),                        ElevatedButton(
                          onPressed: _isEditing
                              ? () => _showDocumentSourceDialog('otherDocumentsUrl', (result) {
                                  if (result != null) {
                                    // UI update is handled in _pickImageAsDocument
                                  }
                                })
                              : null,
                          child: Text(((widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty) ||
                                      (widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty))
                              ? 'Change file' 
                              : 'Upload file'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ((widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty) ||
                                              (widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty))
                                ? Colors.green.shade50 
                                : Colors.white,
                            foregroundColor: ((widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty) ||
                                             (widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty))
                                ? Colors.green.shade700 
                                : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    if ((widget.product['otherDocumentsPath'] != null && widget.product['otherDocumentsPath'].isNotEmpty)) ...[
                      SizedBox(height: 8),
                      Text(
                        'File: ${widget.product['otherDocumentsPath']?.split('/').last ?? 'Other documents'}',
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
              const SizedBox(height: 24),              ElevatedButton(
                onPressed: _isLoading ? null : () => _showDeleteConfirmation(),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Delete', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  padding: const EdgeInsets.symmetric(vertical: 16),
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

  Future<void> _saveProduct() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('products')
          .doc(widget.product['id'])
          .update(widget.product);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Product updated successfully')),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Unable to save product. Please check your information and try again.')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showDocumentSourceDialog(String field, Function(Map<String, String>?) onResult) async {
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
        result = await _pickImageAsDocument(field, source == 'camera' ? ImageSource.camera : ImageSource.gallery);
      } else if (source == 'files') {
        await _pickAndUploadDocument(field);
        return; // The existing method handles UI updates
      }
      onResult(result);
    }
  }  Future<Map<String, String>?> _pickImageAsDocument(String field, ImageSource source) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);
    
    if (image != null) {
      try {
        // ✅ Usar serviço de cópias independentes para documentos
        final String? copiedImagePath = await _imageCopyService.createImageCopy(image.path);
        
        if (copiedImagePath != null) {
          // Update the product data
          setState(() {
            widget.product[field] = '';
            widget.product[field.replaceAll('Url', 'Path')] = copiedImagePath;
          });

          // Update in Firestore
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('products')
              .doc(widget.product['id'])
              .update({
            field: '',
            field.replaceAll('Url', 'Path'): copiedImagePath,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(child: Text('Document added successfully!')),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          
          return {
            'localPath': copiedImagePath,
            'remoteUrl': '',
          };
        } else {
          // Fallback para método original se a cópia falhar
          final Directory appDir = await getApplicationDocumentsDirectory();
          String folderName = 'documents';
          if (field == 'receiptUrl') folderName = 'receipts';
          if (field == 'warrantyUrl') folderName = 'warranties';
          
          final String localDirPath = '${appDir.path}/$folderName';
          final Directory localDir = Directory(localDirPath);
          if (!await localDir.exists()) {
            await localDir.create(recursive: true);
          }
          
          final String fileName = '${const Uuid().v4()}${path.extension(image.path)}';
          final String localPath = '$localDirPath/$fileName';
          
          final File localFile = File(localPath);
          await localFile.writeAsBytes(await image.readAsBytes());
          
          // Update the product data
          setState(() {
            widget.product[field] = '';
            widget.product[field.replaceAll('Url', 'Path')] = localPath;
          });

          // Update in Firestore
          await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('products')
              .doc(widget.product['id'])
              .update({
            field: '',
            field.replaceAll('Url', 'Path'): localPath,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.warning, color: Colors.white),                SizedBox(width: 10),
                  Expanded(child: Text('Document saved with original reference')),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
          
          return {
            'localPath': localPath,
            'remoteUrl': '',
          };
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Error saving document')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    return null;
  }

  Widget _buildDropdownWithAddOption(String label, List<String> options, Map<String, dynamic> product, String key, bool isEnabled) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        DropdownButtonFormField<String>(
          value: options.contains(product[key]) ? product[key] : null,
          items: options.map((option) {
            return DropdownMenuItem<String>(
              value: option,
              child: Text(option),
            );
          }).toList(),
          onChanged: isEnabled
              ? (value) {
                  setState(() {
                    product[key] = value;
                  });
                }
              : null,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        if (isEnabled)
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
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, newController.text),
                        child: const Text('Add'),
                      ),
                    ],
                  );
                },
              );

              if (newValue != null && newValue.isNotEmpty) {
                setState(() {
                  options.add(newValue);
                  product[key] = newValue;
                });
              }
            },
            child: Text('Add New $label'),
          ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red[600], size: 28),
            SizedBox(width: 12),
            Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete this product?', 
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text('Product: ${widget.product['name'] ?? 'Unknown'}', 
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700])),
            SizedBox(height: 12),
            Text('This action cannot be undone.', 
                style: TextStyle(color: Colors.red[700], fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await _deleteProduct();
    }
  }
}


