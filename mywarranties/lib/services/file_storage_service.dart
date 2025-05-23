import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = Uuid();

  // Singleton pattern
  factory FileStorageService() {
    return _instance;
  }

  FileStorageService._internal();

  /// Picks an image from the gallery and saves it locally
  /// Returns a map with the local path and remote URL if uploaded to Firebase
  Future<Map<String, String>?> pickAndStoreImage({required BuildContext context, bool uploadToFirebase = true}) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      try {
        // Copy to local app directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String localDirPath = '${appDir.path}/product_images';
        
        // Create directory if it doesn't exist
        final Directory localDir = Directory(localDirPath);
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
        
        // Generate unique filename
        final String fileName = '${_uuid.v4()}${path.extension(image.path)}';
        final String localPath = '$localDirPath/$fileName';
        
        // Copy file to local storage
        final File localFile = File(localPath);
        await localFile.writeAsBytes(await image.readAsBytes());
        
        // Upload to Firebase if requested
        String? remoteUrl;
        if (uploadToFirebase) {
          final user = _auth.currentUser;
          if (user != null) {
            final storageRef = _storage.ref().child('products/${user.uid}/$fileName');
            await storageRef.putFile(localFile);
            remoteUrl = await storageRef.getDownloadURL();
          }
        }
        
        return {
          'localPath': localPath,
          'remoteUrl': remoteUrl ?? '',
        };
      } catch (e) {
        _showErrorSnackbar(context, 'Error saving image: $e');
      }
    }
    return null;
  }

  /// Picks a document and saves it locally
  /// Returns a map with the local path and remote URL if uploaded to Firebase
  Future<Map<String, String>?> pickAndStoreDocument({
    required BuildContext context, 
    required String folder,
    bool uploadToFirebase = true
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null && result.files.single.path != null) {
      try {
        final File originalFile = File(result.files.single.path!);
        final String fileExt = result.files.single.extension ?? 'file';
        
        // Copy to local app directory
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String localDirPath = '${appDir.path}/$folder';
        
        // Create directory if it doesn't exist
        final Directory localDir = Directory(localDirPath);
        if (!await localDir.exists()) {
          await localDir.create(recursive: true);
        }
        
        // Generate unique filename
        final String fileName = '${_uuid.v4()}.$fileExt';
        final String localPath = '$localDirPath/$fileName';
        
        // Copy file to local storage
        final File localFile = File(localPath);
        await localFile.writeAsBytes(await originalFile.readAsBytes());
        
        // Upload to Firebase if requested
        String? remoteUrl;
        if (uploadToFirebase) {
          final storageRef = _storage.ref().child('$folder/${user.uid}/$fileName');
          await storageRef.putFile(localFile);
          remoteUrl = await storageRef.getDownloadURL();
        }
        
        return {
          'localPath': localPath,
          'remoteUrl': remoteUrl ?? '',
        };
      } catch (e) {
        _showErrorSnackbar(context, 'Error saving document: $e');
      }
    }
    return null;
  }
  
  /// Opens a file from local storage or falls back to remote URL
  Future<void> openFile(BuildContext context, String localPath, String remoteUrl) async {
    try {
      final File file = File(localPath);
      if (await file.exists()) {
        // TODO: Open local file with appropriate viewer
        // For now, we'll just use the remote URL as a fallback
        _openRemoteUrl(context, remoteUrl);
      } else {
        // If local file doesn't exist, try to use the remote URL
        _openRemoteUrl(context, remoteUrl);
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Error opening file: $e');
    }
  }
  
  /// Opens a remote URL
  Future<void> _openRemoteUrl(BuildContext context, String url) async {
    if (url.isEmpty) {
      _showErrorSnackbar(context, 'File URL is not available');
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showErrorSnackbar(context, 'Could not open the file. Please check if it exists.');
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Unable to open the file. The file may be corrupted or inaccessible.');
    }
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 3),
      ),
    );
  }

  /// Deletes a file from local storage and optionally from Firebase
  Future<void> deleteFile(String localPath, String remoteUrl, {bool deleteFromFirebase = true}) async {
    try {
      // Delete from local storage
      final File file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
      
      // Delete from Firebase if requested
      if (deleteFromFirebase && remoteUrl.isNotEmpty) {
        try {
          final Reference ref = _storage.refFromURL(remoteUrl);
          await ref.delete();
        } catch (e) {
          print('Error deleting file from Firebase: $e');
        }
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }

  /// Import dependencies needed for the file_storage_service
  static const List<String> requiredImports = [
    'import:url_launcher/url_launcher.dart',
    'import:path/path.dart',
  ];
}
