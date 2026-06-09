import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageOptimizerService {
  /// Base compression function
  static Future<File> _compress({
    required File file,
    required int maxWidth,
    required int quality,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = p.basenameWithoutExtension(file.path);
    final outPath = p.join(
      tempDir.path, 
      "optimized_${fileName}_${DateTime.now().millisecondsSinceEpoch}.jpg"
    );

    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: quality,
        minWidth: maxWidth,
        format: CompressFormat.jpeg,
      );

      if (result == null) return file;
      return File(result.path);
    } catch (e) {
      debugPrint("Error compressing image: $e");
      return file;
    }
  }

  /// Task 2: QUESTION IMAGE COMPRESSION
  /// Max Width: 1080 px, JPEG Quality: 70
  static Future<File> compressQuestionImage(File file) async {
    return _compress(file: file, maxWidth: 1080, quality: 70);
  }

  /// Task 3: FEED POST IMAGE COMPRESSION
  /// Max Width: 1080 px, JPEG Quality: 70
  static Future<File> compressFeedImage(File file) async {
    return _compress(file: file, maxWidth: 1080, quality: 70);
  }

  /// Task 4: SNAP IMAGE COMPRESSION
  /// Max Width: 720 px, JPEG Quality: 60
  static Future<File> compressSnapImage(File file) async {
    return _compress(file: file, maxWidth: 720, quality: 60);
  }
}
