import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

/// Serviço para criar cópias independentes de documentos/ficheiros
/// Garante que os ficheiros permanecem acessíveis mesmo se o utilizador 
/// os remover da localização original
class FileCopyService {
  static final FileCopyService _instance = FileCopyService._internal();
  final Uuid _uuid = Uuid();

  // Singleton pattern
  factory FileCopyService() {
    return _instance;
  }

  FileCopyService._internal();

  /// Cria uma cópia independente de um ficheiro
  /// [originalPath] - Caminho do ficheiro original
  /// [documentType] - Tipo de documento ('receipts', 'warranties', 'documents')
  /// Retorna o caminho da cópia ou null se falhar
  Future<String?> createFileCopy(String originalPath, String documentType) async {
    try {
      print('🔄 FileCopyService: Iniciando cópia de ficheiro...');
      print('📁 Ficheiro original: $originalPath');
      print('📋 Tipo de documento: $documentType');

      // Verificar se o ficheiro original existe
      final File originalFile = File(originalPath);
      if (!await originalFile.exists()) {
        print('❌ Ficheiro original não existe: $originalPath');
        return null;
      }

      // Obter diretório de documentos da aplicação
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String copyDirPath = '${appDir.path}/document_copies/$documentType';
      
      // Criar diretório se não existir
      final Directory copyDir = Directory(copyDirPath);
      if (!await copyDir.exists()) {
        await copyDir.create(recursive: true);
        print('📁 Diretório criado: $copyDirPath');
      }

      // Gerar nome único para a cópia
      final String originalExtension = path.extension(originalPath);
      final String fileName = '${_uuid.v4()}$originalExtension';
      final String copyPath = '$copyDirPath/$fileName';

      print('🎯 Caminho da cópia: $copyPath');

      // Criar a cópia
      final File copyFile = File(copyPath);
      final List<int> bytes = await originalFile.readAsBytes();
      await copyFile.writeAsBytes(bytes);

      // Verificar se a cópia foi criada com sucesso
      if (await copyFile.exists()) {
        final int originalSize = await originalFile.length();
        final int copySize = await copyFile.length();
        
        if (originalSize == copySize) {
          print('✅ Cópia criada com sucesso!');
          print('📊 Tamanho: $copySize bytes');
          return copyPath;
        } else {
          print('❌ Erro: Tamanhos não coincidem (original: $originalSize, cópia: $copySize)');
          // Limpar cópia inválida
          await copyFile.delete();
          return null;
        }
      } else {
        print('❌ Erro: Cópia não foi criada');
        return null;
      }

    } catch (e) {
      print('❌ Erro ao criar cópia do ficheiro: $e');
      return null;
    }
  }

  /// Remove uma cópia de ficheiro
  /// [copyPath] - Caminho da cópia a remover
  Future<bool> removeFileCopy(String copyPath) async {
    try {
      final File copyFile = File(copyPath);
      if (await copyFile.exists()) {
        await copyFile.delete();
        print('🗑️ Cópia removida: $copyPath');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Erro ao remover cópia: $e');
      return false;
    }
  }

  /// Verifica se uma cópia existe e está acessível
  /// [copyPath] - Caminho da cópia a verificar
  Future<bool> isFileCopyValid(String copyPath) async {
    try {
      if (copyPath.isEmpty) return false;
      
      final File copyFile = File(copyPath);
      return await copyFile.exists();
    } catch (e) {
      print('❌ Erro ao verificar cópia: $e');
      return false;
    }
  }

  /// Obtém informações sobre uma cópia de ficheiro
  /// [copyPath] - Caminho da cópia
  /// Retorna um mapa com informações do ficheiro
  Future<Map<String, dynamic>?> getFileCopyInfo(String copyPath) async {
    try {
      final File copyFile = File(copyPath);
      if (!await copyFile.exists()) return null;

      final FileStat stat = await copyFile.stat();
      final String fileName = path.basename(copyPath);
      final String extension = path.extension(copyPath);
      
      return {
        'name': fileName,
        'extension': extension,
        'size': stat.size,
        'modified': stat.modified,
        'isValid': true,
      };
    } catch (e) {
      print('❌ Erro ao obter informações da cópia: $e');
      return null;
    }
  }

  /// Limpa cópias antigas (opcional - para manutenção)
  /// [olderThanDays] - Remove cópias mais antigas que X dias
  Future<int> cleanupOldCopies({int olderThanDays = 30}) async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String baseCopyDir = '${appDir.path}/document_copies';
      final Directory copyDir = Directory(baseCopyDir);
      
      if (!await copyDir.exists()) return 0;

      int deletedCount = 0;
      final DateTime cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
      
      await for (FileSystemEntity entity in copyDir.list(recursive: true)) {
        if (entity is File) {
          final FileStat stat = await entity.stat();
          if (stat.modified.isBefore(cutoffDate)) {
            await entity.delete();
            deletedCount++;
          }
        }
      }
      
      print('🧹 Limpeza concluída: $deletedCount ficheiros removidos');
      return deletedCount;
    } catch (e) {
      print('❌ Erro na limpeza: $e');
      return 0;
    }
  }

  /// Obtém o tamanho total ocupado pelas cópias
  Future<int> getTotalCopiesSize() async {
    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String baseCopyDir = '${appDir.path}/document_copies';
      final Directory copyDir = Directory(baseCopyDir);
      
      if (!await copyDir.exists()) return 0;

      int totalSize = 0;
      await for (FileSystemEntity entity in copyDir.list(recursive: true)) {
        if (entity is File) {
          final FileStat stat = await entity.stat();
          totalSize += stat.size;
        }
      }
      
      return totalSize;
    } catch (e) {
      print('❌ Erro ao calcular tamanho: $e');
      return 0;
    }
  }
}
