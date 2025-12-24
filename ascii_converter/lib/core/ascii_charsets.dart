import 'package:characters/characters.dart';

/// ASCII Character Set Definitions
///
/// Character sets are ordered from dark (low brightness) to light (high brightness).
/// The converter maps pixel brightness to character index, so the first character
/// represents the darkest pixels and the last represents the brightest.
class AsciiCharset {
  final String name;
  final String chars;

  const AsciiCharset({required this.name, required this.chars});

  List<String> get charList => chars.characters.toList();
  int get length => charList.length;
}

enum CharsetKey {
  standard,
  blocks,
  minimal,
  binary,
  detailed,
  dots,
  arrows,
  emoji,
}

const Map<CharsetKey, AsciiCharset> asciiCharsets = {
  /// Classic 10-character gradient - good balance of detail and performance
  CharsetKey.standard: AsciiCharset(
    name: "Standard",
    chars: " .:-=+*#%@",
  ),

  /// Unicode block characters - chunky retro aesthetic
  CharsetKey.blocks: AsciiCharset(
    name: "Blocks",
    chars: " ░▒▓█",
  ),

  /// Minimal 5-character set - high contrast, fast rendering
  CharsetKey.minimal: AsciiCharset(
    name: "Minimal",
    chars: " .oO@",
  ),

  /// Binary on/off - pure silhouette mode
  CharsetKey.binary: AsciiCharset(
    name: "Binary",
    chars: " █",
  ),

  /// 70-character gradient - maximum detail, best for high resolution
  CharsetKey.detailed: AsciiCharset(
    name: "Detailed",
    chars: " .'`^\",:;Il!i><~+_-?][}{1)(|/tfjrxnuvczXYUJCLQ0OZmwqpdbkhao*#MW&8%B\$",
  ),

  /// Dot-based - pointillist aesthetic
  CharsetKey.dots: AsciiCharset(
    name: "Dots",
    chars: " ·•●",
  ),

  /// Directional arrows - experimental
  CharsetKey.arrows: AsciiCharset(
    name: "Arrows",
    chars: " ←↙↓↘→↗↑↖",
  ),

  /// Moon phases - decorative gradient
  CharsetKey.emoji: AsciiCharset(
    name: "Emoji",
    chars: "  ░▒▓🌑🌒🌓🌔🌕",
  ),
};

const CharsetKey defaultCharset = CharsetKey.standard;

AsciiCharset getCharset(CharsetKey key) {
  return asciiCharsets[key] ?? asciiCharsets[defaultCharset]!;
}
