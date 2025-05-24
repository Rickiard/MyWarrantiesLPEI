import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/image_copy_service.dart';
import '../services/file_copy_service.dart';
import '../services/storage_management_service.dart';

/// Utility class for verifying the file handling system implementation
class FileHandlingVerification {
  
  /// Verify that all required services are properly implemented
  static Future<Map<String, bool>> verifyImplementation() async {
    Map<String, bool> results = {};
    
    try {
      // Test ImageCopyService
      results['ImageCopyService.instantiation'] = await _testImageCopyService();
      
      // Test FileCopyService  
      results['FileCopyService.instantiation'] = await _testFileCopyService();
      
      // Test StorageManagementService
      results['StorageManagementService.storageStats'] = await _testStorageManagementService();
      
      // Test directory structure
      results['DirectoryStructure.created'] = await _testDirectoryStructure();
      
    } catch (e) {
      debugPrint('Error during verification: $e');
      results['Error'] = false;
    }
    
    return results;
  }
  
  static Future<bool> _testImageCopyService() async {
    try {
      // Test if we can get the app image directory
      ImageCopyService imageService = ImageCopyService();
      String appImageDir = await imageService.getAppImageDirectory();
      return appImageDir.isNotEmpty && appImageDir.contains('product_images');
    } catch (e) {
      debugPrint('ImageCopyService test failed: $e');
      return false;
    }
  }
    static Future<bool> _testFileCopyService() async {
    try {
      // Test if FileCopyService can be instantiated
      FileCopyService();
      return true; // Service exists and can be instantiated
    } catch (e) {
      debugPrint('FileCopyService test failed: $e');
      return false;
    }
  }
  
  static Future<bool> _testStorageManagementService() async {
    try {
      // Test if we can get storage statistics
      Map<String, dynamic> stats = await StorageManagementService.getStorageStats();
      
      return stats.containsKey('totalFiles') && 
             stats.containsKey('totalSizeBytes') &&
             stats.containsKey('imageFiles') &&
             stats.containsKey('documentFiles');
    } catch (e) {
      debugPrint('StorageManagementService test failed: $e');
      return false;
    }
  }
  
  static Future<bool> _testDirectoryStructure() async {
    try {
      // Test directory creation for images
      ImageCopyService imageService = ImageCopyService();
      String imageDir = await imageService.getAppImageDirectory();
      
      // Check if image directory exists or can be created
      bool imageDirExists = Directory(imageDir).existsSync();
      
      if (!imageDirExists) {
        await Directory(imageDir).create(recursive: true);
        imageDirExists = Directory(imageDir).existsSync();
      }
      
      return imageDirExists;
    } catch (e) {
      debugPrint('Directory structure test failed: $e');
      return false;
    }
  }
  
  /// Print a verification report
  static Future<void> printVerificationReport() async {
    debugPrint('=== MyWarranties File Handling System Verification ===');
    
    Map<String, bool> results = await verifyImplementation();
    
    results.forEach((test, passed) {
      String status = passed ? '✅ PASS' : '❌ FAIL';
      debugPrint('$status $test');
    });
    
    int passedCount = results.values.where((v) => v).length;
    int totalCount = results.length;
    
    debugPrint('');
    debugPrint('Summary: $passedCount/$totalCount tests passed');
    
    if (passedCount == totalCount) {
      debugPrint('🎉 All file handling services are working correctly!');
    } else {
      debugPrint('⚠️  Some tests failed. Please check the implementation.');
    }
    
    debugPrint('=== End Verification Report ===');
  }
  
  /// Quick test to verify if services are working
  static Future<bool> quickVerify() async {
    try {
      Map<String, bool> results = await verifyImplementation();
      return results.values.every((test) => test);
    } catch (e) {
      debugPrint('Quick verification failed: $e');
      return false;
    }
  }
  
  /// Test image copying functionality with a real file
  static Future<bool> testImageCopy(String sourcePath) async {
    try {
      ImageCopyService imageService = ImageCopyService();
      String? copiedPath = await imageService.createImageCopy(sourcePath);
      if (copiedPath != null) {
        File copiedFile = File(copiedPath);
        bool exists = await copiedFile.exists();
        debugPrint('Image copy test: ${exists ? "SUCCESS" : "FAILED"} - $copiedPath');
        return exists;
      }
      return false;
    } catch (e) {
      debugPrint('Image copy test failed: $e');
      return false;
    }
  }
  
  /// Test file copying functionality with a real file
  static Future<bool> testFileCopy(String sourcePath, String documentType) async {
    try {
      FileCopyService fileService = FileCopyService();
      String? copiedPath = await fileService.createFileCopy(sourcePath, documentType);
      if (copiedPath != null) {
        File copiedFile = File(copiedPath);
        bool exists = await copiedFile.exists();
        debugPrint('File copy test ($documentType): ${exists ? "SUCCESS" : "FAILED"} - $copiedPath');
        return exists;
      }
      return false;
    } catch (e) {
      debugPrint('File copy test failed: $e');
      return false;
    }
  }
  
  /// Get detailed information about the file handling system
  static Future<Map<String, dynamic>> getSystemInfo() async {
    Map<String, dynamic> info = {};
    
    try {
      // Test services
      info['services'] = await verifyImplementation();
      
      // Get storage stats
      try {
        info['storageStats'] = await StorageManagementService.getStorageStats();
      } catch (e) {
        info['storageStats'] = {'error': e.toString()};
      }
      
      // Get image directory info
      try {
        ImageCopyService imageService = ImageCopyService();
        info['imageDirectory'] = await imageService.getAppImageDirectory();
      } catch (e) {
        info['imageDirectory'] = {'error': e.toString()};
      }
      
    } catch (e) {
      info['error'] = e.toString();
    }
    
    return info;
  }
}
