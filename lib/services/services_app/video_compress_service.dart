// lib/services/services_app/video_compress_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

// ══════════════════════════════════════════════════════════════════════════════
//  VIDEO COMPRESS SERVICE
//
//  Responsável por:
//    • Comprimir vídeos antes do upload (redução drástica de tamanho)
//    • Gerar thumbnail automático (frame do início do vídeo)
//    • Gerar thumbnail em posição específica (para seleção de capa pelo usuário)
//    • Reportar progresso de compressão via callback
//
//  Dependência no pubspec.yaml:
//    flutter_video_compress: ^0.3.x
//
//  Permissões:
//    Android → READ_EXTERNAL_STORAGE / READ_MEDIA_VIDEO (já cobertas pelo image_picker)
//    iOS     → NSPhotoLibraryUsageDescription (já no Info.plist do image_picker)
// ══════════════════════════════════════════════════════════════════════════════

class VideoCompressService {
  VideoCompressService._();
  static final VideoCompressService instance = VideoCompressService._();

  // ══════════════════════════════════════════════════════════════════════════
  //  COMPRIMIR VÍDEO
  //  VideoQuality.MediumQuality → redução de ~60-80% no tamanho
  // ══════════════════════════════════════════════════════════════════════════
  Future<File?> compress(
    File input, {
    VideoQuality quality = VideoQuality.MediumQuality,
    void Function(double progress)? onProgress,
  }) async {
    try {
      Subscription? sub;

      if (onProgress != null) {
        sub = VideoCompress.compressProgress$.subscribe((p) {
          onProgress(p / 100.0); // 0.0 → 1.0
        });
      }

      final info = await VideoCompress.compressVideo(
        input.absolute.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );

      sub?.unsubscribe();

      if (info?.file == null) return null;
      return info!.file!;
    } catch (e) {
      debugPrint('[VideoCompressService] Erro ao comprimir: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GERAR THUMBNAIL AUTOMÁTICO (bytes)
  //  position: -1 → usa o primeiro frame disponível
  // ══════════════════════════════════════════════════════════════════════════
  Future<Uint8List?> generateThumbnail(File videoFile) async {
    try {
      return await VideoCompress.getByteThumbnail(
        videoFile.absolute.path,
        quality: 85,
        position: -1,
      );
    } catch (e) {
      debugPrint('[VideoCompressService] Erro thumbnail: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GERAR THUMBNAIL EM POSIÇÃO ESPECÍFICA (bytes)
  //  Usado pelo seletor de capa — positionMs é a posição em milissegundos
  //  escolhida pelo usuário via slider.
  // ══════════════════════════════════════════════════════════════════════════
  Future<Uint8List?> generateThumbnailAt(File videoFile, int positionMs) async {
    try {
      return await VideoCompress.getByteThumbnail(
        videoFile.absolute.path,
        quality: 85,
        position: positionMs,
      );
    } catch (e) {
      debugPrint('[VideoCompressService] Erro thumbnail at $positionMs ms: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  GERAR THUMBNAIL (File) — para upload direto no Storage
  // ══════════════════════════════════════════════════════════════════════════
  Future<File?> generateThumbnailFile(File videoFile) async {
    try {
      return await VideoCompress.getFileThumbnail(
        videoFile.absolute.path,
        quality: 85,
        position: -1,
      );
    } catch (e) {
      debugPrint('[VideoCompressService] Erro thumbnail file: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CANCELAR COMPRESSÃO EM ANDAMENTO
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> cancelCompression() async {
    try {
      await VideoCompress.cancelCompression();
    } catch (_) {}
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UTILITÁRIO — tamanho legível (ex: "4.2 MB")
  // ══════════════════════════════════════════════════════════════════════════
  static String fileSizeMB(File file) {
    final bytes = file.lengthSync();
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}