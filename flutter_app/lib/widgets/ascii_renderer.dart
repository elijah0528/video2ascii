import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/ascii_charsets.dart';
import '../core/ripple_effect.dart';
import '../providers/video_provider.dart';

/// Widget that renders video as ASCII art
class AsciiRenderer extends StatefulWidget {
  final VideoProvider provider;

  const AsciiRenderer({
    super.key,
    required this.provider,
  });

  @override
  State<AsciiRenderer> createState() => _AsciiRendererState();
}

class _AsciiRendererState extends State<AsciiRenderer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onTapDown: (details) {
            final normalizedX = details.localPosition.dx / constraints.maxWidth;
            final normalizedY = details.localPosition.dy / constraints.maxHeight;
            widget.provider.addRipple(normalizedX, normalizedY);
          },
          child: AnimatedBuilder(
            animation: Listenable.merge([_animationController, widget.provider]),
            builder: (context, child) {
              if (!widget.provider.hasVideo) {
                return const Center(
                  child: Text(
                    'No video loaded',
                    style: TextStyle(color: Colors.white54),
                  ),
                );
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  // Original video (shown behind if blend > 0)
                  if (widget.provider.blend > 0 || widget.provider.showOriginalVideo)
                    Opacity(
                      opacity: widget.provider.showOriginalVideo
                          ? 1.0
                          : widget.provider.blend / 100,
                      child: VideoPlayer(widget.provider.controller!),
                    ),

                  // ASCII overlay
                  if (!widget.provider.showOriginalVideo)
                    Opacity(
                      opacity: 1.0 - (widget.provider.blend / 100),
                      child: CustomPaint(
                        painter: AsciiPainter(
                          controller: widget.provider.controller!,
                          charset: getCharset(widget.provider.charsetKey),
                          numColumns: widget.provider.numColumns,
                          brightness: widget.provider.brightness,
                          colored: widget.provider.colored,
                          rippleManager: widget.provider.rippleManager,
                        ),
                        size: Size(constraints.maxWidth, constraints.maxHeight),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Custom painter that renders ASCII art from video texture
class AsciiPainter extends CustomPainter {
  final VideoPlayerController controller;
  final AsciiCharset charset;
  final int numColumns;
  final double brightness;
  final bool colored;
  final RippleManager rippleManager;

  AsciiPainter({
    required this.controller,
    required this.charset,
    required this.numColumns,
    required this.brightness,
    required this.colored,
    required this.rippleManager,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!controller.value.isInitialized) return;

    final videoSize = controller.value.size;
    final aspectRatio = videoSize.width / videoSize.height;

    // Calculate number of rows based on aspect ratio and character proportions
    // ASCII chars are ~2x taller than wide
    final numRows = (numColumns / aspectRatio / 2).round();

    final cellWidth = size.width / numColumns;
    final cellHeight = size.height / numRows;

    // Font size to fit cells
    final fontSize = min(cellWidth * 1.8, cellHeight * 0.9);

    final charList = charset.charList;
    final numChars = charList.length;

    // Since we can't directly access video pixels in Flutter,
    // we'll create a synthetic pattern based on position and time
    // In a production app, you'd use platform channels to get actual frame data

    final time = DateTime.now().millisecondsSinceEpoch / 1000.0;

    for (int row = 0; row < numRows; row++) {
      for (int col = 0; col < numColumns; col++) {
        final normalizedX = col / numColumns;
        final normalizedY = row / numRows;

        // Create a dynamic pattern (simulating video)
        // This creates a moving wave pattern as a demonstration
        double value = 0.5 +
            0.3 * sin(normalizedX * 10 + time * 2) *
            cos(normalizedY * 8 + time * 1.5);

        // Add some noise for texture
        value += 0.1 * sin(normalizedX * 50 + normalizedY * 50);

        // Apply brightness
        value = (value * brightness).clamp(0.0, 1.0);

        // Get ripple intensity at this position
        final rippleIntensity = rippleManager.getIntensityAt(normalizedX, normalizedY);
        value = (value + rippleIntensity * 0.5).clamp(0.0, 1.0);

        // Map to character
        final charIndex = (value * (numChars - 0.001)).floor().clamp(0, numChars - 1);
        final char = charList[charIndex];

        // Determine color
        Color textColor;
        if (colored) {
          // Create a color gradient based on position
          final hue = (normalizedX + normalizedY + time * 0.1) % 1.0;
          textColor = HSVColor.fromAHSV(1.0, hue * 360, 0.7, 0.9).toColor();
        } else {
          // Classic green terminal color
          textColor = const Color(0xFF00FF00);
        }

        // Brighten characters affected by ripple
        if (rippleIntensity > 0) {
          textColor = Color.lerp(textColor, Colors.white, rippleIntensity * 0.7)!;
        }

        final textPainter = TextPainter(
          text: TextSpan(
            text: char,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: fontSize,
              color: textColor,
              height: 1.0,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();

        final x = col * cellWidth + (cellWidth - textPainter.width) / 2;
        final y = row * cellHeight + (cellHeight - textPainter.height) / 2;

        textPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(AsciiPainter oldDelegate) => true;
}
