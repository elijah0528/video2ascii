import 'ascii_charsets.dart';

/// Preset configurations for different target devices/formats
class ConversionPreset {
  final String name;
  final String description;
  final int numColumns;
  final double brightness;
  final CharsetKey charsetKey;
  final double targetAspectRatio; // width/height (0.5625 for 9:16, 1.0 for square)
  final int fps;

  const ConversionPreset({
    required this.name,
    required this.description,
    required this.numColumns,
    this.brightness = 1.0,
    this.charsetKey = CharsetKey.standard,
    this.targetAspectRatio = 0.5625, // 9:16 portrait
    this.fps = 20,
  });

  /// Calculate number of rows based on columns and aspect ratio
  int get numRows {
    // ASCII chars are ~2x taller than wide, so we compensate
    return (numColumns / targetAspectRatio / 2).round();
  }

  /// Bytes per frame estimate
  int get bytesPerFrame => numColumns * numRows * 4;

  /// Display resolution string
  String get resolution => '${numColumns}x$numRows';
}

/// Built-in presets for common formats
class ConversionPresets {
  static const iPhonePortraitHD = ConversionPreset(
    name: 'iPhone Portrait HD',
    description: '9:16 vertical, high detail for Pro displays',
    numColumns: 120,
    targetAspectRatio: 0.5625, // 9:16
    fps: 20,
  );

  static const iPhonePortraitSD = ConversionPreset(
    name: 'iPhone Portrait SD',
    description: '9:16 vertical, balanced size/quality',
    numColumns: 80,
    targetAspectRatio: 0.5625, // 9:16
    fps: 20,
  );

  static const iPhonePortraitLow = ConversionPreset(
    name: 'iPhone Portrait Compact',
    description: '9:16 vertical, minimal file size',
    numColumns: 60,
    targetAspectRatio: 0.5625, // 9:16
    fps: 15,
  );

  static const squareHD = ConversionPreset(
    name: 'Square HD',
    description: '1:1 square, high detail',
    numColumns: 100,
    targetAspectRatio: 1.0,
    fps: 20,
  );

  static const squareSD = ConversionPreset(
    name: 'Square SD',
    description: '1:1 square, balanced',
    numColumns: 70,
    targetAspectRatio: 1.0,
    fps: 20,
  );

  static const landscapeHD = ConversionPreset(
    name: 'Landscape HD',
    description: '16:9 horizontal, high detail',
    numColumns: 140,
    targetAspectRatio: 1.7778, // 16:9
    fps: 20,
  );

  static const landscapeSD = ConversionPreset(
    name: 'Landscape SD',
    description: '16:9 horizontal, balanced',
    numColumns: 100,
    targetAspectRatio: 1.7778, // 16:9
    fps: 20,
  );

  static const retro = ConversionPreset(
    name: 'Retro Terminal',
    description: 'Classic 80x24 terminal look',
    numColumns: 80,
    charsetKey: CharsetKey.standard,
    targetAspectRatio: 0.5625,
    fps: 15,
    brightness: 1.2,
  );

  static const blocky = ConversionPreset(
    name: 'Blocky',
    description: 'Unicode blocks for chunky aesthetic',
    numColumns: 60,
    charsetKey: CharsetKey.blocks,
    targetAspectRatio: 0.5625,
    fps: 20,
  );

  static const minimal = ConversionPreset(
    name: 'Minimal',
    description: 'High contrast, few characters',
    numColumns: 80,
    charsetKey: CharsetKey.minimal,
    targetAspectRatio: 0.5625,
    fps: 20,
    brightness: 1.3,
  );

  static const all = [
    iPhonePortraitHD,
    iPhonePortraitSD,
    iPhonePortraitLow,
    squareHD,
    squareSD,
    landscapeHD,
    landscapeSD,
    retro,
    blocky,
    minimal,
  ];
}
