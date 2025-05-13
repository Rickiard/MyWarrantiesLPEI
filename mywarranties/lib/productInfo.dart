import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  final _warrantyExtensionUnitController = TextEditingController();
  final List<String> _timeUnits = ['days', 'months', 'years', 'lifetime'];

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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

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

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;

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
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        widget.product['imageUrl'] = pickedFile.path;
      });
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
      backgroundColor: const Color(0xFFAFE1F0),
      appBar: AppBar(
        title: const Text('Product Information'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
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
            children: [
              GestureDetector(
                onTap: _isEditing ? _pickImage : null,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: widget.product['imageUrl'] != null && widget.product['imageUrl'].toString().isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(widget.product['imageUrl']),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.image_not_supported, size: 60, color: Colors.grey);
                            },
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.upload, size: 40, color: Colors.grey),
                            Text('Add Photo', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

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
              const SizedBox(height: 24),

              const Text('View and Upload Documents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty
                          ? () => _launchUrl(widget.product['receiptUrl'])
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt,
                            color: widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'View Receipt',
                            style: TextStyle(
                              color: widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty
                                  ? Colors.blue
                                  : Colors.grey,
                              decoration: widget.product['receiptUrl'] != null && widget.product['receiptUrl'].isNotEmpty
                                  ? TextDecoration.underline
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isEditing
                        ? () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setState(() {
                                widget.product['receiptUrl'] = pickedFile.path;
                              });
                            }
                          }
                        : null,
                    child: const Text('Upload'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty
                          ? () => _launchUrl(widget.product['warrantyUrl'])
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            Icons.verified,
                            color: widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'View Warranty',
                            style: TextStyle(
                              color: widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty
                                  ? Colors.blue
                                  : Colors.grey,
                              decoration: widget.product['warrantyUrl'] != null && widget.product['warrantyUrl'].isNotEmpty
                                  ? TextDecoration.underline
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isEditing
                        ? () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setState(() {
                                widget.product['warrantyUrl'] = pickedFile.path;
                              });
                            }
                          }
                        : null,
                    child: const Text('Upload'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty
                          ? () => _launchUrl(widget.product['otherDocumentsUrl'])
                          : null,
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder,
                            color: widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty
                                ? Colors.blue
                                : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'View Other Documents',
                            style: TextStyle(
                              color: widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty
                                  ? Colors.blue
                                  : Colors.grey,
                              decoration: widget.product['otherDocumentsUrl'] != null && widget.product['otherDocumentsUrl'].isNotEmpty
                                  ? TextDecoration.underline
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isEditing
                        ? () async {
                            final picker = ImagePicker();
                            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                            if (pickedFile != null) {
                              setState(() {
                                widget.product['otherDocumentsUrl'] = pickedFile.path;
                              });
                            }
                          }
                        : null,
                    child: const Text('Upload'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _deleteProduct,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Delete', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[300],
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
}
