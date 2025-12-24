import 'dart:typed_data';
import 'dart:ui' as ui;
import 'ascii_charsets.dart';

/// Represents a single ASCII character with optional color
class AsciiChar {
  final String char;
  final int r, g, b;

  const AsciiChar(this.char, this.r, this.g, this.b);
}

/// Result of ASCII conversion containing the character grid
class AsciiFrame {
  final List<List<AsciiChar>> grid;
  final int width;
  final int height;

  const AsciiFrame({
    required this.grid,
    required this.width,
    required this.height,
  });
}

/// Converts images/video frames to ASCII art
class AsciiConverter {
  CharsetKey _charsetKey = defaultCharset;
  double _brightness = 1.0;
  bool _colored = true;
  int _numColumns = 80;

  CharsetKey get charsetKey => _charsetKey;
  set charsetKey(CharsetKey value) => _charsetKey = value;

  double get brightness => _brightness;
  set brightness(double value) => _brightness = value.clamp(0.0, 2.0);

  bool get colored => _colored;
  set colored(bool value) => _colored = value;

  int get numColumns => _numColumns;
  set numColumns(int value) => _numColumns = value.clamp(20, 200);

  /// Convert raw RGBA pixel data to ASCII frame
  AsciiFrame convertPixels({
    required Uint8List pixels,
    required int imageWidth,
    required int imageHeight,
  }) {
    final charset = getCharset(_charsetKey);
    final charList = charset.charList;
    final numChars = charList.length;

    // Calculate grid dimensions maintaining aspect ratio
    // ASCII chars are typically ~2x taller than wide, so we compensate
    final aspectRatio = imageWidth / imageHeight;
    final numRows = (_numColumns / aspectRatio / 2).round();

    // Cell dimensions
    final cellWidth = imageWidth / _numColumns;
    final cellHeight = imageHeight / numRows;

    final grid = <List<AsciiChar>>[];

    for (int row = 0; row < numRows; row++) {
      final rowChars = <AsciiChar>[];

      for (int col = 0; col < _numColumns; col++) {
        // Sample from center of cell
        final sampleX = ((col + 0.5) * cellWidth).round().clamp(0, imageWidth - 1);
        final sampleY = ((row + 0.5) * cellHeight).round().clamp(0, imageHeight - 1);

        // Get pixel data (RGBA format)
        final pixelIndex = (sampleY * imageWidth + sampleX) * 4;
        final r = pixels[pixelIndex];
        final g = pixels[pixelIndex + 1];
        final b = pixels[pixelIndex + 2];

        // Calculate brightness using human eye sensitivity weighting
        // Same formula as original: dot(RGB, [0.299, 0.587, 0.114])
        double luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;

        // Apply brightness multiplier
        luma = (luma * _brightness).clamp(0.0, 1.0);

        // Map to character index
        final charIndex = (luma * (numChars - 0.001)).floor().clamp(0, numChars - 1);

        rowChars.add(AsciiChar(charList[charIndex], r, g, b));
      }

      grid.add(rowChars);
    }

    return AsciiFrame(
      grid: grid,
      width: _numColumns,
      height: numRows,
    );
  }

  /// Convert a Flutter Image to ASCII frame
  Future<AsciiFrame?> convertImage(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return null;

    return convertPixels(
      pixels: byteData.buffer.asUint8List(),
      imageWidth: image.width,
      imageHeight: image.height,
    );
  }
}
