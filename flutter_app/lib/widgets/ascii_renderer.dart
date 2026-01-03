import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';
import '../core/ascii_charsets.dart';
import '../core/ascii_frame_cache.dart';
import '../core/ripple_effect.dart';
import '../providers/video_provider.dart';

/// Widget that renders video as ASCII art with real frame capture
class AsciiRenderer extends StatefulWidget {
  final VideoProvider provider;

  const AsciiRenderer({
    super.key,
    required this.provider,
  });

  @override
  State<AsciiRenderer> createState() => _AsciiRendererState();
}

class _AsciiRendererState extends State<AsciiRenderer>
    with SingleTickerProviderStateMixin {
  final GlobalKey _videoKey = GlobalKey();
  late AnimationController _animationController;
  Timer? _captureTimer;
  Uint8List? _framePixels;
  int _frameWidth = 0;
  int _frameHeight = 0;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    // Start frame capture timer at ~20fps for performance
    _captureTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _captureFrame();
    });
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _captureFrame() async {
    if (_isCapturing) return;
    if (!widget.provider.hasVideo) return;

    // Skip capture if playing from cache
    if (widget.provider.playbackMode == PlaybackMode.cached) return;

    if (!widget.provider.isPlaying && _framePixels != null) return;

    final boundary = _videoKey.currentContext?.findRenderObject();
    if (boundary == null || boundary is! RenderRepaintBoundary) return;

    try {
      _isCapturing = true;

      // Capture at a lower resolution for performance
      const double pixelRatio = 0.5;
      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);

      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      if (byteData != null && mounted) {
        final pixels = byteData.buffer.asUint8List();

        setState(() {
          _framePixels = pixels;
          _frameWidth = image.width;
          _frameHeight = image.height;
        });

        // Record frame if in recording mode
        if (widget.provider.playbackMode == PlaybackMode.recording) {
          widget.provider.recordFrame(
            timestampMs: widget.provider.position.inMilliseconds,
            pixels: pixels,
            imageWidth: image.width,
            imageHeight: image.height,
          );
        }
      }

      image.dispose();
    } catch (e) {
      // Silently handle capture errors
    } finally {
      _isCapturing = false;
    }
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
                  // Hidden video for frame capture (wrapped in RepaintBoundary)
                  Positioned.fill(
                    child: Opacity(
                      opacity: widget.provider.showOriginalVideo ? 1.0 : 0.0,
                      child: RepaintBoundary(
                        key: _videoKey,
                        child: VideoPlayer(widget.provider.controller!),
                      ),
                    ),
                  ),

                  // Original video visible (if blend > 0)
                  if (widget.provider.blend > 0 && !widget.provider.showOriginalVideo)
                    Opacity(
                      opacity: widget.provider.blend / 100,
                      child: VideoPlayer(widget.provider.controller!),
                    ),

                  // ASCII overlay
                  if (!widget.provider.showOriginalVideo)
                    Opacity(
                      opacity: 1.0 - (widget.provider.blend / 100),
                      child: CustomPaint(
                        painter: AsciiPainter(
                          framePixels: _framePixels,
                          frameWidth: _frameWidth,
                          frameHeight: _frameHeight,
                          videoSize: widget.provider.controller!.value.size,
                          charset: getCharset(widget.provider.charsetKey),
                          numColumns: widget.provider.numColumns,
                          brightness: widget.provider.brightness,
                          colored: widget.provider.colored,
                          rippleManager: widget.provider.rippleManager,
                          // Cached playback support
                          cachedFrame: widget.provider.getCachedFrame(),
                          playbackMode: widget.provider.playbackMode,
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

/// Custom painter that renders ASCII art from captured video frames
class AsciiPainter extends CustomPainter {
  final Uint8List? framePixels;
  final int frameWidth;
  final int frameHeight;
  final Size videoSize;
  final AsciiCharset charset;
  final int numColumns;
  final double brightness;
  final bool colored;
  final RippleManager rippleManager;
  // Cached playback support
  final CompressedFrame? cachedFrame;
  final PlaybackMode playbackMode;

  AsciiPainter({
    required this.framePixels,
    required this.frameWidth,
    required this.frameHeight,
    required this.videoSize,
    required this.charset,
    required this.numColumns,
    required this.brightness,
    required this.colored,
    required this.rippleManager,
    this.cachedFrame,
    this.playbackMode = PlaybackMode.live,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (videoSize.isEmpty) return;

    // Use cached frame dimensions if in cached mode
    final useCached = playbackMode == PlaybackMode.cached && cachedFrame != null;

    final aspectRatio = videoSize.width / videoSize.height;
    final effectiveNumColumns = useCached ? cachedFrame!.width : numColumns;
    final numRows = useCached ? cachedFrame!.height : max(1, (numColumns / aspectRatio / 2).round());

    final cellWidth = size.width / effectiveNumColumns;
    final cellHeight = size.height / numRows;
    final fontSize = min(cellWidth * 1.8, cellHeight * 0.9);

    final charList = charset.charList;
    final numChars = charList.length;

    // Check if we have valid frame data
    final hasFrameData = framePixels != null &&
        frameWidth > 0 &&
        frameHeight > 0;

    for (int row = 0; row < numRows; row++) {
      for (int col = 0; col < effectiveNumColumns; col++) {
        final normalizedX = col / effectiveNumColumns;
        final normalizedY = row / numRows;

        double value;
        int r = 0, g = 255, b = 0; // Default green
        String char;

        if (useCached) {
          // FAST PATH: Render from compressed cache
          final charIdx = cachedFrame!.getCharIndex(col, row);
          final rgb = cachedFrame!.getRGB(col, row);
          r = rgb.$1;
          g = rgb.$2;
          b = rgb.$3;
          char = charList[charIdx.clamp(0, numChars - 1)];
          value = charIdx / numChars; // Approximate for ripple
        } else if (hasFrameData) {
          // Sample from actual frame data
          final sampleX = (normalizedX * frameWidth).round().clamp(0, frameWidth - 1);
          final sampleY = (normalizedY * frameHeight).round().clamp(0, frameHeight - 1);
          final pixelIndex = (sampleY * frameWidth + sampleX) * 4;

          if (pixelIndex + 3 < framePixels!.length) {
            r = framePixels![pixelIndex];
            g = framePixels![pixelIndex + 1];
            b = framePixels![pixelIndex + 2];

            // Calculate brightness using human eye sensitivity weighting
            value = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
          } else {
            value = 0.5;
          }

          // Apply brightness multiplier
          value = (value * brightness).clamp(0.0, 1.0);

          // Map to character
          final charIndex = (value * (numChars - 0.001)).floor().clamp(0, numChars - 1);
          char = charList[charIndex];
        } else {
          // Fallback: animated pattern while loading
          final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
          value = 0.5 +
              0.3 * sin(normalizedX * 10 + time * 2) *
                  cos(normalizedY * 8 + time * 1.5);
          value += 0.1 * sin(normalizedX * 50 + normalizedY * 50);

          // Apply brightness multiplier
          value = (value * brightness).clamp(0.0, 1.0);

          // Map to character
          final charIndex = (value * (numChars - 0.001)).floor().clamp(0, numChars - 1);
          char = charList[charIndex];
        }

        // Get ripple intensity
        final rippleIntensity = rippleManager.getIntensityAt(normalizedX, normalizedY);
        if (!useCached) {
          value = (value + rippleIntensity * 0.5).clamp(0.0, 1.0);
        }

        // Determine color
        Color textColor;
        if (colored && (hasFrameData || useCached)) {
          // Use actual video color
          textColor = Color.fromRGBO(r, g, b, 1.0);
          // Boost saturation slightly for visibility
          final hsv = HSVColor.fromColor(textColor);
          textColor = hsv.withSaturation((hsv.saturation * 1.3).clamp(0.0, 1.0))
              .withValue((hsv.value * 1.2).clamp(0.0, 1.0))
              .toColor();
        } else if (colored) {
          // Animated color gradient while loading
          final time = DateTime.now().millisecondsSinceEpoch / 1000.0;
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
