import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

class FileStorageService {
  static final FileStorageService _instance = FileStorageService._internal();
  final Uuid _uuid = Uuid();

  // Singleton pattern
  factory FileStorageService() {
    return _instance;
  }

  FileStorageService._internal();

  /// Picks an image from the gallery and saves it locally
  /// Returns a map with the local path
  Future<Map<String, String>?> pickAndStoreImage({required BuildContext context}) async {
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
        
        return {
          'localPath': localPath,
          'remoteUrl': '', // Empty string as we're not using Firebase Storage
        };
      } catch (e) {
        _showErrorSnackbar(context, 'Error saving image: $e');
      }
    }
    return null;
  }

  /// Picks a document and saves it locally
  Future<Map<String, String>?> pickAndStoreDocument({
    required BuildContext context, 
    required String folder,
  }) async {
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
        
        return {
          'localPath': localPath,
          'remoteUrl': '', // Empty string as we're not using Firebase Storage
        };
      } catch (e) {
        _showErrorSnackbar(context, 'Error saving document: $e');
      }
    }
    return null;
  }
  
  /// Opens a file from local storage
  Future<void> openFile(BuildContext context, String localPath) async {
    try {
      final File file = File(localPath);
      if (await file.exists()) {
        final uri = Uri.file(localPath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          _showErrorSnackbar(context, 'Could not open the file. No suitable app found to open this file type.');
        }
      } else {
        _showErrorSnackbar(context, 'File not found. It may have been deleted or moved.');
      }
    } catch (e) {
      _showErrorSnackbar(context, 'Error opening file: $e');
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

  /// Deletes a file from local storage
  Future<void> deleteFile(String localPath) async {
    try {
      // Delete from local storage
      final File file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('Error deleting file: $e');
    }
  }
  
  /// Get a file's icon based on its extension
  IconData getFileIcon(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    
    switch (extension) {
      case '.pdf':
        return Icons.picture_as_pdf;
      case '.doc':
      case '.docx':
        return Icons.description;
      case '.xls':
      case '.xlsx':
        return Icons.table_chart;
      case '.ppt':
      case '.pptx':
        return Icons.slideshow;
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
        return Icons.image;
      default:
        return Icons.insert_drive_file;
    }
  }
}
