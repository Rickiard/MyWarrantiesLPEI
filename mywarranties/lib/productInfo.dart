import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class ProductInfoPage extends StatefulWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onDelete;

  const ProductInfoPage({Key? key, required this.product, this.onDelete}) : super(key: key);

  @override
  State<ProductInfoPage> createState() => _ProductInfoPageState();
}

class _ProductInfoPageState extends State<ProductInfoPage> {
  bool _isLoading = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting product: $e')),
        );
      }
    } finally {
      if (mounted) {
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
            const SnackBar(content: Text('Could not open the file')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening file: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFAFE1F0),
      appBar: AppBar(
        title: const Text('Product Information'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Product Image
                  Center(
                    child: Container(
                      height: 120,
                      width: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: widget.product['imageUrl'] != null && widget.product['imageUrl'].toString().isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                widget.product['imageUrl'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.image_not_supported, size: 60, color: Colors.grey);
                                },
                              ),
                            )
                          : const Icon(Icons.image, size: 60, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Info fields
                  _infoField('Product Name', widget.product['name']),
                  _infoField('Product Category', widget.product['category']),
                  _infoField('Product Price', widget.product['price']),
                  _infoField('Purchase Date', widget.product['purchaseDate']),
                  _infoField('Warranty Period', widget.product['warrantyPeriod']),
                  _infoField('Store Name', widget.product['storeDetails']),
                  _infoField('Product Brand', widget.product['brand']),
                  const SizedBox(height: 8),
                  // Notes
                  const Text('Other Notes', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    padding: const EdgeInsets.all(8),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.product['notes'] ?? '',
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text('View Documents', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _docRow('Receipt', widget.product['receiptUrl']),
                  _docRow('Warranty', widget.product['warrantyUrl']),
                  _docRow('Other Documents', widget.product['otherDocumentsUrl']),
                  const SizedBox(height: 24),
                  // Delete Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _deleteProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[300],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white),
                          )
                        : const Text('Delete', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _infoField(String label, dynamic value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value?.toString() ?? '',
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _docRow(String label, String? url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: url != null && url.isNotEmpty
                ? () => _launchUrl(url)
                : null,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
            child: const Text('View file'),
          ),
        ],
      ),
    );
  }
}
