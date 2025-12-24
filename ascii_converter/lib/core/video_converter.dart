import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'ascii_charsets.dart';
import 'ascii_frame_cache.dart';
import 'conversion_preset.dart';

/// Status of a video in the conversion queue
enum VideoStatus {
  pending,
  extracting,
  converting,
  saving,
  completed,
  failed,
}

/// Represents a video file to be converted
class VideoItem {
  final String path;
  final String name;
  VideoStatus status;
  double progress;
  String? error;
  int? frameCount;
  Duration? duration;
  String? outputPath;

  VideoItem({
    required this.path,
    required this.name,
    this.status = VideoStatus.pending,
    this.progress = 0.0,
    this.error,
    this.frameCount,
    this.duration,
    this.outputPath,
  });

  String get statusText {
    switch (status) {
      case VideoStatus.pending:
        return 'Waiting...';
      case VideoStatus.extracting:
        return 'Extracting frames...';
      case VideoStatus.converting:
        return 'Converting ${(progress * 100).toInt()}%';
      case VideoStatus.saving:
        return 'Saving...';
      case VideoStatus.completed:
        return 'Done!';
      case VideoStatus.failed:
        return 'Failed: ${error ?? "Unknown error"}';
    }
  }
}

/// Batch video to ASCII converter
class VideoConverter extends ChangeNotifier {
  final List<VideoItem> _videos = [];
  ConversionPreset _preset = ConversionPresets.iPhonePortraitSD;
  bool _isConverting = false;
  int _currentIndex = 0;
  String? _outputDirectory;

  List<VideoItem> get videos => List.unmodifiable(_videos);
  ConversionPreset get preset => _preset;
  bool get isConverting => _isConverting;
  int get currentIndex => _currentIndex;
  String? get outputDirectory => _outputDirectory;

  int get totalVideos => _videos.length;
  int get completedVideos => _videos.where((v) => v.status == VideoStatus.completed).length;
  int get failedVideos => _videos.where((v) => v.status == VideoStatus.failed).length;

  set preset(ConversionPreset value) {
    _preset = value;
    notifyListeners();
  }

  /// Add video files to the queue
  void addVideos(List<String> paths) {
    for (final path in paths) {
      if (!_videos.any((v) => v.path == path)) {
        final name = path.split('/').last;
        _videos.add(VideoItem(path: path, name: name));
      }
    }
    notifyListeners();
  }

  /// Remove a video from the queue
  void removeVideo(int index) {
    if (index >= 0 && index < _videos.length) {
      _videos.removeAt(index);
      notifyListeners();
    }
  }

  /// Clear all videos
  void clearAll() {
    _videos.clear();
    notifyListeners();
  }

  /// Set output directory
  void setOutputDirectory(String path) {
    _outputDirectory = path;
    notifyListeners();
  }

  /// Start batch conversion
  Future<void> startConversion() async {
    if (_isConverting) return;
    if (_videos.isEmpty) return;

    _isConverting = true;
    notifyListeners();

    // Set default output directory if not set
    if (_outputDirectory == null) {
      final docs = await getApplicationDocumentsDirectory();
      _outputDirectory = '${docs.path}/ascii_cache';
      await Directory(_outputDirectory!).create(recursive: true);
    }

    for (int i = 0; i < _videos.length; i++) {
      if (!_isConverting) break; // Allow cancellation

      final video = _videos[i];
      if (video.status == VideoStatus.completed) continue;

      _currentIndex = i;
      await _convertVideo(video);
      notifyListeners();
    }

    _isConverting = false;
    notifyListeners();
  }

  /// Stop conversion
  void stopConversion() {
    _isConverting = false;
    notifyListeners();
  }

  /// Convert a single video
  Future<void> _convertVideo(VideoItem video) async {
    try {
      video.status = VideoStatus.extracting;
      video.progress = 0.0;
      notifyListeners();

      // Create temp directory for frames
      final tempDir = await getTemporaryDirectory();
      final framesDir = Directory('${tempDir.path}/frames_${DateTime.now().millisecondsSinceEpoch}');
      await framesDir.create();

      // Get video duration and extract frames
      final fps = _preset.fps;
      final framePattern = '${framesDir.path}/frame_%04d.png';

      // Extract frames using system FFmpeg
      final result = await Process.run('ffmpeg', [
        '-i', video.path,
        '-vf', 'fps=$fps',
        '-f', 'image2',
        framePattern,
      ]);

      if (result.exitCode != 0) {
        throw Exception('FFmpeg failed: ${result.stderr}');
      }

      // Get list of extracted frames
      final frameFiles = await framesDir
          .list()
          .where((f) => f.path.endsWith('.png'))
          .toList();
      frameFiles.sort((a, b) => a.path.compareTo(b.path));

      video.frameCount = frameFiles.length;
      video.status = VideoStatus.converting;
      notifyListeners();

      if (frameFiles.isEmpty) {
        throw Exception('No frames extracted');
      }

      // Initialize cache
      final cache = AsciiFrameCache();
      cache.startRecording(
        videoId: video.name.replaceAll('.mp4', ''),
        numColumns: _preset.numColumns,
        brightness: _preset.brightness,
        charsetKey: _preset.charsetKey,
        frameIntervalMs: (1000 / fps).round(),
      );

      // Process each frame
      for (int i = 0; i < frameFiles.length; i++) {
        if (!_isConverting) {
          video.status = VideoStatus.failed;
          video.error = 'Cancelled';
          break;
        }

        final frameFile = frameFiles[i] as File;
        final bytes = await frameFile.readAsBytes();

        // Decode image
        final codec = await ui.instantiateImageCodec(bytes);
        final frameInfo = await codec.getNextFrame();
        final image = frameInfo.image;

        // Get pixel data
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          cache.addFrame(
            timestampMs: (i * 1000 / fps).round(),
            pixels: byteData.buffer.asUint8List(),
            imageWidth: image.width,
            imageHeight: image.height,
          );
        }

        image.dispose();
        video.progress = (i + 1) / frameFiles.length;
        notifyListeners();
      }

      // Save to output directory
      if (video.status != VideoStatus.failed) {
        video.status = VideoStatus.saving;
        notifyListeners();

        // Set custom output path
        final outputName = video.name.replaceAll('.mp4', '.ascache');
        video.outputPath = '$_outputDirectory/$outputName';

        // Save using custom path
        await _saveCache(cache, video.outputPath!);

        video.status = VideoStatus.completed;
      }

      // Cleanup temp frames
      await framesDir.delete(recursive: true);
      cache.clear();

    } catch (e) {
      video.status = VideoStatus.failed;
      video.error = e.toString();
    }

    notifyListeners();
  }

  /// Save cache to custom path
  Future<void> _saveCache(AsciiFrameCache cache, String outputPath) async {
    final file = File(outputPath);
    final parentDir = file.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    // Build binary format
    final buffer = BytesBuilder();

    // Magic bytes "ASC\0"
    buffer.add([0x41, 0x53, 0x43, 0x00]);

    // Version
    buffer.addByte(1);

    // NumColumns (2 bytes)
    buffer.addByte((cache.numColumns >> 8) & 0xFF);
    buffer.addByte(cache.numColumns & 0xFF);

    // Brightness * 100 (2 bytes)
    final brightnessInt = (cache.brightness * 100).round();
    buffer.addByte((brightnessInt >> 8) & 0xFF);
    buffer.addByte(brightnessInt & 0xFF);

    // Charset key index (1 byte)
    buffer.addByte(CharsetKey.values.indexOf(cache.charsetKey));

    // Frame interval (2 bytes) - use 50ms default
    buffer.addByte(0);
    buffer.addByte(50);

    // Frame count (4 bytes)
    buffer.addByte((cache.frameCount >> 24) & 0xFF);
    buffer.addByte((cache.frameCount >> 16) & 0xFF);
    buffer.addByte((cache.frameCount >> 8) & 0xFF);
    buffer.addByte(cache.frameCount & 0xFF);

    // Frames
    for (final frame in cache.frames) {
      // Width (2 bytes)
      buffer.addByte((frame.width >> 8) & 0xFF);
      buffer.addByte(frame.width & 0xFF);

      // Height (2 bytes)
      buffer.addByte((frame.height >> 8) & 0xFF);
      buffer.addByte(frame.height & 0xFF);

      // Data length (4 bytes)
      final len = frame.data.length;
      buffer.addByte((len >> 24) & 0xFF);
      buffer.addByte((len >> 16) & 0xFF);
      buffer.addByte((len >> 8) & 0xFF);
      buffer.addByte(len & 0xFF);

      // Data
      buffer.add(frame.data);
    }

    await file.writeAsBytes(buffer.toBytes());
  }
}
