// lib/services/services_app/video_watermark_service.dart
//
// Marca d'água para vídeos com níveis de intensidade configuráveis.
//
// USO:
//   // Feed - marca discreta
//   final file = await VideoWatermarkService.apply(
//     videoFile:   original,
//     userName:    'JOÃO',
//     videoWidth:  1280,
//     videoHeight: 720,
//     level:       WatermarkLevel.minimal, // <-- aqui
//   );
//
//   // Download - marca completa
//   final file = await VideoWatermarkService.apply(
//     videoFile:   original,
//     userName:    'JOÃO',
//     videoWidth:  1280,
//     videoHeight: 720,
//     level:       WatermarkLevel.full, // <-- proteção máxima
//   );

import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:ffmpeg_kit_flutter_new/statistics.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'watermark_service.dart';

class VideoWatermarkService {
  VideoWatermarkService._();

  /// Aplica marca d'água permanente no vídeo.
  ///
  /// [level] define a intensidade:
  ///   • minimal  → feed (quase invisível)
  ///   • balanced → visualização normal
  ///   • full     → download/compartilhamento
  static Future<File?> apply({
    required File videoFile,
    required String userName,
    required int videoWidth,
    required int videoHeight,
    WatermarkLevel level = WatermarkLevel.balanced,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final tmp = await getTemporaryDirectory();
      final ts  = DateTime.now().millisecondsSinceEpoch;

      // ── 1. Gera overlay PNG com o nível escolhido ──────────────────────────
      debugPrint('[VideoWatermark] Gerando overlay ${videoWidth}x$videoHeight (nível: $level)…');
      final overlayBytes = await WatermarkService.createOverlayPng(
        width:    videoWidth,
        height:   videoHeight,
        userName: userName,
        level:    level, // <-- repassa o nível
      );

      final overlayPath = '${tmp.path}/wm_overlay_$ts.png';
      await File(overlayPath).writeAsBytes(overlayBytes);
      debugPrint('[VideoWatermark] Overlay salvo: $overlayPath');

      // ── 2. Caminho de saída ────────────────────────────────────────────────
      final outputPath = '${tmp.path}/wm_video_$ts.mp4';

      // ── 3. Comando FFmpeg ───────────────────────────────────────────────────
      final cmd = [
        '-y',
        '-i', '"${videoFile.absolute.path}"',
        '-i', '"$overlayPath"',
        '-filter_complex',
        '"[0:v][1:v]overlay=0:0:format=auto,format=yuv420p"',
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-crf', '23',
        '-c:a', 'copy',
        '"$outputPath"',
      ].join(' ');

      debugPrint('[VideoWatermark] Executando: ffmpeg $cmd');

      // ── 4. Progresso ────────────────────────────────────────────────────────
      int? totalDurationUs;
      FFmpegKitConfig.enableStatisticsCallback((Statistics stats) {
        if (onProgress == null) return;
        final time = stats.getTime();
        if (time <= 0) return;
        totalDurationUs ??= _estimateDurationMs(videoFile);
        if (totalDurationUs != null && totalDurationUs! > 0) {
          final pct = (time / totalDurationUs!).clamp(0.0, 0.95);
          onProgress(pct);
        }
      });

      final session    = await FFmpegKit.execute(cmd);
      final returnCode = await session.getReturnCode();

      // ── 5. Limpeza ──────────────────────────────────────────────────────────
      try { File(overlayPath).deleteSync(); } catch (_) {}
      FFmpegKitConfig.enableStatisticsCallback(null);

      if (!ReturnCode.isSuccess(returnCode)) {
        final logs = await session.getLogsAsString();
        debugPrint('[VideoWatermark] ❌ FFmpeg falhou (rc=$returnCode):\n$logs');
        return null;
      }

      onProgress?.call(1.0);
      debugPrint('[VideoWatermark] ✅ Concluído: $outputPath');
      return File(outputPath);
    } catch (e, st) {
      debugPrint('[VideoWatermark] ❌ Exceção: $e\n$st');
      return null;
    }
  }

  static int _estimateDurationMs(File file) {
    const bitrateKbps = 2000;
    final sizeKb = file.lengthSync() / 1024;
    return ((sizeKb / bitrateKbps) * 1000).round().clamp(1000, 60000);
  }
}