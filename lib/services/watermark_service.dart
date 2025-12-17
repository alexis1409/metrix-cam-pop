import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../models/app_settings.dart';

class WatermarkData {
  final String storeName;
  final String storeId;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final String? userName;
  final WatermarkConfig config;

  WatermarkData({
    required this.storeName,
    required this.storeId,
    this.latitude,
    this.longitude,
    DateTime? timestamp,
    this.userName,
    WatermarkConfig? config,
  }) : timestamp = timestamp ?? DateTime.now(),
       config = config ?? WatermarkConfig();
}

class WatermarkService {
  static const int _padding = 20;
  static const int _lineHeight = 30;

  /// Adds a watermark to the image and returns the path to the new image
  Future<String> addWatermark(String imagePath, WatermarkData data) async {
    // Read the image
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Could not decode image');
    }

    // Prepare watermark text lines
    final lines = _buildWatermarkLines(data);

    // Calculate watermark area dimensions
    final textHeight = lines.length * _lineHeight + _padding * 2;
    final watermarkY = image.height - textHeight - _padding;

    // Draw semi-transparent background for text readability
    _drawWatermarkBackground(image, watermarkY, textHeight);

    // Draw each line of text
    _drawWatermarkText(image, lines, watermarkY);

    // Save the watermarked image
    final outputPath = await _saveWatermarkedImage(image, imagePath);

    return outputPath;
  }

  List<String> _buildWatermarkLines(WatermarkData data) {
    final lines = <String>[];
    final config = data.config;

    // Date and time (based on config)
    if (config.mostrarFecha || config.mostrarHora) {
      final dateStr = _formatDateTime(data.timestamp,
        showDate: config.mostrarFecha,
        showTime: config.mostrarHora);
      lines.add(dateStr);
    }

    // Store info
    if (config.mostrarTienda) {
      lines.add('${data.storeName} (#${data.storeId})');
    }

    // Coordinates
    if (config.mostrarCoordenadas && data.latitude != null && data.longitude != null) {
      lines.add('GPS: ${data.latitude!.toStringAsFixed(6)}, ${data.longitude!.toStringAsFixed(6)}');
    }

    // User name if available
    if (config.mostrarUsuario && data.userName != null && data.userName!.isNotEmpty) {
      lines.add('Usuario: ${data.userName}');
    }

    return lines;
  }

  String _formatDateTime(DateTime dt, {bool showDate = true, bool showTime = true}) {
    final parts = <String>[];

    if (showDate) {
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      parts.add('$day/$month/$year');
    }

    if (showTime) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      final second = dt.second.toString().padLeft(2, '0');
      parts.add('$hour:$minute:$second');
    }

    return parts.join(' ');
  }

  void _drawWatermarkBackground(img.Image image, int startY, int height) {
    // Draw a semi-transparent dark background
    for (int y = startY; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        // Blend with dark overlay (50% opacity black)
        final r = ((pixel.r.toInt() * 0.5) + (0 * 0.5)).toInt();
        final g = ((pixel.g.toInt() * 0.5) + (0 * 0.5)).toInt();
        final b = ((pixel.b.toInt() * 0.5) + (0 * 0.5)).toInt();
        image.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }

  void _drawWatermarkText(img.Image image, List<String> lines, int startY) {
    final font = img.arial24;
    int currentY = startY + _padding;

    for (final line in lines) {
      img.drawString(
        image,
        line,
        font: font,
        x: _padding,
        y: currentY,
        color: img.ColorRgba8(255, 255, 255, 255), // White text
      );
      currentY += _lineHeight;
    }
  }

  Future<String> _saveWatermarkedImage(img.Image image, String originalPath) async {
    // Get temp directory for saving
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '${tempDir.path}/watermarked_$timestamp.jpg';

    // Encode as JPEG with good quality
    final encodedBytes = img.encodeJpg(image, quality: 90);

    // Write to file
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(encodedBytes);

    return outputPath;
  }
}
