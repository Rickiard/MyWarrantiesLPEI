import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

/// Serviço para criar cópias independentes de imagens
/// Garante que a aplicação não depende dos ficheiros originais
class ImageCopyService {
  static final ImageCopyService _instance = ImageCopyService._internal();
  final Uuid _uuid = Uuid();

  factory ImageCopyService() {
    return _instance;
  }

  ImageCopyService._internal();

  /// Obtém o diretório privado da aplicação para imagens de produtos
  /// Cria o diretório se não existir
  Future<String> getAppImageDirectory() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imageDir = Directory('${appDir.path}/product_images');
      
      if (!await imageDir.exists()) {
        await imageDir.create(recursive: true);
      }
      
      return imageDir.path;
    } catch (e) {
      print('Erro ao criar diretório de imagens: $e');
      rethrow;
    }
  }

  /// Cria uma cópia independente da imagem no diretório privado da aplicação
  /// 
  /// [originalPath] - Caminho da imagem original (galeria/câmara)
  /// Retorna o caminho da cópia criada ou null se houver erro
  Future<String?> createImageCopy(String originalPath) async {
    try {
      final File originalFile = File(originalPath);
      
      // Verifica se o ficheiro original existe
      if (!await originalFile.exists()) {
        print('Ficheiro original não existe: $originalPath');
        return null;
      }

      // Obtém o diretório privado da aplicação
      final String appImageDir = await getAppImageDirectory();
      
      // Cria nome único para evitar conflitos
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String uuid = _uuid.v4().substring(0, 8); // Usar apenas parte do UUID
      final String extension = path.extension(originalPath);
      final String newFileName = 'product_${timestamp}_$uuid$extension';
      final String newPath = '$appImageDir/$newFileName';
      
      // Fazer cópia física do ficheiro
      final File copiedFile = await originalFile.copy(newPath);
      
      print('✅ Imagem copiada com sucesso:');
      print('   Original: $originalPath');
      print('   Cópia: $newPath');
      
      return copiedFile.path;
    } catch (e) {
      print('❌ Erro ao copiar imagem: $e');
      print('   Caminho original: $originalPath');
      return null;
    }
  }

  /// Elimina uma imagem do diretório privado da aplicação
  /// [imagePath] - Caminho da imagem a eliminar
  Future<bool> deleteImageCopy(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      
      // Verifica se o ficheiro está no diretório da aplicação
      final String appImageDir = await getAppImageDirectory();
      if (!imagePath.startsWith(appImageDir)) {
        print('⚠️ Tentativa de eliminar ficheiro fora do diretório da app: $imagePath');
        return false;
      }
      
      if (await imageFile.exists()) {
        await imageFile.delete();
        print('🗑️ Imagem eliminada: $imagePath');
        return true;
      } else {
        print('⚠️ Ficheiro não existe para eliminar: $imagePath');
        return false;
      }
    } catch (e) {
      print('❌ Erro ao eliminar imagem: $e');
      return false;
    }
  }

  /// Limpa todas as imagens orfãs (não referenciadas na base de dados)
  /// Útil para limpeza periódica de espaço
  Future<void> cleanupOrphanedImages() async {
    try {
      final String appImageDir = await getAppImageDirectory();
      final Directory imageDir = Directory(appImageDir);
      
      if (await imageDir.exists()) {
        final List<FileSystemEntity> files = await imageDir.list().toList();
        print('🧹 Encontrados ${files.length} ficheiros no diretório de imagens');
        
        // Aqui poderia implementar lógica para verificar quais imagens
        // estão referenciadas na base de dados e eliminar as não referenciadas
        // Por agora, apenas regista o número de ficheiros
      }
    } catch (e) {
      print('❌ Erro na limpeza de imagens orfãs: $e');
    }
  }

  /// Obtém informações sobre o uso de espaço de imagens
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final String appImageDir = await getAppImageDirectory();
      final Directory imageDir = Directory(appImageDir);
      
      if (!await imageDir.exists()) {
        return {
          'totalFiles': 0,
          'totalSizeBytes': 0,
          'totalSizeMB': 0.0,
        };
      }
      
      final List<FileSystemEntity> files = await imageDir.list().toList();
      int totalSize = 0;
      
      for (var file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }
      
      return {
        'totalFiles': files.length,
        'totalSizeBytes': totalSize,
        'totalSizeMB': totalSize / (1024 * 1024),
      };
    } catch (e) {
      print('❌ Erro ao obter informações de armazenamento: $e');
      return {
        'totalFiles': 0,
        'totalSizeBytes': 0,
        'totalSizeMB': 0.0,
      };
    }
  }
}
