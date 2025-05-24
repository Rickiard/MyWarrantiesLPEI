import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for managing storage and cleaning up orphaned files
class StorageManagementService {
  static const String _imagesFolder = 'app_images';
  static const String _documentsFolder = 'app_documents';
  
  /// Get all file paths referenced in Firestore
  static Future<Set<String>> _getReferencedFiles(String userId) async {
    Set<String> referencedFiles = {};
    
    try {
      // Get all products for the user
      QuerySnapshot productsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('products')
          .get();
      
      for (QueryDocumentSnapshot doc in productsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Add product image if exists
        if (data['imagePath'] != null) {
          referencedFiles.add(data['imagePath'].toString());
        }
        
        // Add receipt if exists
        if (data['receipt'] != null) {
          referencedFiles.add(data['receipt'].toString());
        }
        
        // Add warranty document if exists
        if (data['warranty'] != null) {
          referencedFiles.add(data['warranty'].toString());
        }
        
        // Add other documents if they exist
        if (data['documents'] != null && data['documents'] is List) {
          List<dynamic> documents = data['documents'];
          for (var doc in documents) {
            if (doc is String) {
              referencedFiles.add(doc);
            } else if (doc is Map<String, dynamic> && doc['path'] != null) {
              referencedFiles.add(doc['path'].toString());
            }
          }
        }
      }
      
      // Get user profile picture
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
        if (userData['profilePicture'] != null) {
          referencedFiles.add(userData['profilePicture'].toString());
        }
      }
      
    } catch (e) {
      print('Error getting referenced files: $e');
    }
    
    return referencedFiles;
  }
  
  /// Get all files in the app directories
  static Future<Set<String>> _getAllAppFiles() async {
    Set<String> allFiles = {};
    
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      
      // Check images folder
      Directory imagesDir = Directory(path.join(appDocDir.path, _imagesFolder));
      if (await imagesDir.exists()) {
        await for (FileSystemEntity entity in imagesDir.list(recursive: true)) {
          if (entity is File) {
            allFiles.add(entity.path);
          }
        }
      }
      
      // Check documents folders
      Directory documentsDir = Directory(path.join(appDocDir.path, _documentsFolder));
      if (await documentsDir.exists()) {
        await for (FileSystemEntity entity in documentsDir.list(recursive: true)) {
          if (entity is File) {
            allFiles.add(entity.path);
          }
        }
      }
      
    } catch (e) {
      print('Error getting app files: $e');
    }
    
    return allFiles;
  }
  
  /// Find orphaned files that are not referenced in Firestore
  static Future<List<String>> findOrphanedFiles(String userId) async {
    Set<String> referencedFiles = await _getReferencedFiles(userId);
    Set<String> allFiles = await _getAllAppFiles();
    
    List<String> orphanedFiles = [];
    
    for (String filePath in allFiles) {
      bool isReferenced = false;
      
      // Check if this file path is referenced
      for (String referencedPath in referencedFiles) {
        if (referencedPath == filePath || referencedPath.endsWith(path.basename(filePath))) {
          isReferenced = true;
          break;
        }
      }
      
      if (!isReferenced) {
        orphanedFiles.add(filePath);
      }
    }
    
    return orphanedFiles;
  }
  
  /// Clean up orphaned files
  static Future<int> cleanupOrphanedFiles(String userId) async {
    List<String> orphanedFiles = await findOrphanedFiles(userId);
    int deletedCount = 0;
    
    for (String filePath in orphanedFiles) {
      try {
        File file = File(filePath);
        if (await file.exists()) {
          await file.delete();
          deletedCount++;
          print('Deleted orphaned file: $filePath');
        }
      } catch (e) {
        print('Error deleting file $filePath: $e');
      }
    }
    
    return deletedCount;
  }
  
  /// Get storage usage statistics
  static Future<Map<String, dynamic>> getStorageStats() async {
    Map<String, dynamic> stats = {
      'totalFiles': 0,
      'totalSizeBytes': 0,
      'imageFiles': 0,
      'imageSizeBytes': 0,
      'documentFiles': 0,
      'documentSizeBytes': 0,
    };
    
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      
      // Check images folder
      Directory imagesDir = Directory(path.join(appDocDir.path, _imagesFolder));
      if (await imagesDir.exists()) {
        await for (FileSystemEntity entity in imagesDir.list(recursive: true)) {
          if (entity is File) {
            FileStat fileStat = await entity.stat();
            stats['totalFiles']++;
            stats['imageFiles']++;
            stats['totalSizeBytes'] += fileStat.size;
            stats['imageSizeBytes'] += fileStat.size;
          }
        }
      }
      
      // Check documents folder
      Directory documentsDir = Directory(path.join(appDocDir.path, _documentsFolder));
      if (await documentsDir.exists()) {
        await for (FileSystemEntity entity in documentsDir.list(recursive: true)) {
          if (entity is File) {
            FileStat fileStat = await entity.stat();
            stats['totalFiles']++;
            stats['documentFiles']++;
            stats['totalSizeBytes'] += fileStat.size;
            stats['documentSizeBytes'] += fileStat.size;
          }
        }
      }
      
    } catch (e) {
      print('Error getting storage stats: $e');
    }
    
    return stats;
  }
  
  /// Format bytes to human readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
