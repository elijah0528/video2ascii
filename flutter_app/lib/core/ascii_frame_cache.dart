import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'ascii_charsets.dart';

/// Compressed frame data - 4 bytes per cell (charIndex + RGB)
/// Much smaller than storing full AsciiChar objects
class CompressedFrame {
  final Uint8List data; // [charIndex, r, g, b] per cell
  final int width;      // numColumns
  final int height;     // numRows

  const CompressedFrame({
    required this.data,
    required this.width,
    required this.height,
  });

  int get cellCount => width * height;
  int get byteSize => data.length;

  /// Get character index at position
  int getCharIndex(int col, int row) {
    final idx = (row * width + col) * 4;
    return data[idx];
  }

  /// Get RGB at position
  (int r, int g, int b) getRGB(int col, int row) {
    final idx = (row * width + col) * 4;
    return (data[idx + 1], data[idx + 2], data[idx + 3]);
  }
}

/// Manages cached ASCII frames for a video
class AsciiFrameCache {
  final List<CompressedFrame> _frames = [];
  final Map<int, int> _timestampToFrame = {}; // ms -> frame index

  // Metadata for cache validation
  String? _videoId;
  int _numColumns = 0;
  double _brightness = 1.0;
  CharsetKey _charsetKey = defaultCharset;
  int _frameIntervalMs = 50; // Capture interval

  bool _isRecording = false;
  bool _isLoaded = false;

  // Getters
  List<CompressedFrame> get frames => _frames;
  int get frameCount => _frames.length;
  bool get isEmpty => _frames.isEmpty;
  bool get isRecording => _isRecording;
  bool get isLoaded => _isLoaded;
  String? get videoId => _videoId;
  int get numColumns => _numColumns;
  double get brightness => _brightness;
  CharsetKey get charsetKey => _charsetKey;

  /// Estimated memory usage in bytes
  int get memoryUsage {
    int total = 0;
    for (final frame in _frames) {
      total += frame.byteSize;
    }
    return total;
  }

  /// Estimated memory usage as human-readable string
  String get memoryUsageString {
    final bytes = memoryUsage;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Start recording frames for a video
  void startRecording({
    required String videoId,
    required int numColumns,
    required double brightness,
    required CharsetKey charsetKey,
    int frameIntervalMs = 50,
  }) {
    clear();
    _videoId = videoId;
    _numColumns = numColumns;
    _brightness = brightness;
    _charsetKey = charsetKey;
    _frameIntervalMs = frameIntervalMs;
    _isRecording = true;
  }

  /// Stop recording
  void stopRecording() {
    _isRecording = false;
  }

  /// Add a frame to the cache during recording
  void addFrame({
    required int timestampMs,
    required Uint8List pixels,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (!_isRecording) return;

    final charset = getCharset(_charsetKey);
    final charList = charset.charList;
    final numChars = charList.length;

    // Calculate grid dimensions (same logic as AsciiConverter)
    final aspectRatio = imageWidth / imageHeight;
    final numRows = (_numColumns / aspectRatio / 2).round();

    final cellWidth = imageWidth / _numColumns;
    final cellHeight = imageHeight / numRows;

    // Allocate compressed data: 4 bytes per cell
    final data = Uint8List(numRows * _numColumns * 4);
    var dataIdx = 0;

    for (int row = 0; row < numRows; row++) {
      for (int col = 0; col < _numColumns; col++) {
        // Sample from center of cell
        final sampleX = ((col + 0.5) * cellWidth).round().clamp(0, imageWidth - 1);
        final sampleY = ((row + 0.5) * cellHeight).round().clamp(0, imageHeight - 1);

        // Get pixel (RGBA format)
        final pixelIndex = (sampleY * imageWidth + sampleX) * 4;
        final r = pixels[pixelIndex];
        final g = pixels[pixelIndex + 1];
        final b = pixels[pixelIndex + 2];

        // Calculate brightness
        double luma = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        luma = (luma * _brightness).clamp(0.0, 1.0);

        // Map to character index
        final charIndex = (luma * (numChars - 0.001)).floor().clamp(0, numChars - 1);

        // Store compressed: charIndex, R, G, B
        data[dataIdx++] = charIndex;
        data[dataIdx++] = r;
        data[dataIdx++] = g;
        data[dataIdx++] = b;
      }
    }

    final frame = CompressedFrame(
      data: data,
      width: _numColumns,
      height: numRows,
    );

    _timestampToFrame[timestampMs] = _frames.length;
    _frames.add(frame);
  }

  /// Get frame by index
  CompressedFrame? getFrame(int index) {
    if (index < 0 || index >= _frames.length) return null;
    return _frames[index];
  }

  /// Get frame closest to timestamp
  CompressedFrame? getFrameAtTime(int timestampMs) {
    if (_frames.isEmpty) return null;

    // Find closest frame
    final frameIndex = (timestampMs / _frameIntervalMs).round().clamp(0, _frames.length - 1);
    return _frames[frameIndex];
  }

  /// Get frame index for timestamp
  int getFrameIndexForTime(int timestampMs) {
    if (_frames.isEmpty) return 0;
    return (timestampMs / _frameIntervalMs).round().clamp(0, _frames.length - 1);
  }

  /// Clear all cached frames
  void clear() {
    _frames.clear();
    _timestampToFrame.clear();
    _videoId = null;
    _isRecording = false;
    _isLoaded = false;
  }

  // ========== Disk Persistence ==========

  /// Get cache directory
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/ascii_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate safe filename from video ID
  String _safeFileName(String videoId) {
    return videoId.replaceAll(RegExp(r'[^\w\-.]'), '_');
  }

  /// Save cache to disk
  Future<bool> saveToDisk() async {
    if (_frames.isEmpty || _videoId == null) return false;

    try {
      final cacheDir = await _getCacheDir();
      final fileName = _safeFileName(_videoId!);
      final file = File('${cacheDir.path}/$fileName.ascache');

      // Build binary format:
      // Header: [magic(4), version(1), numColumns(2), brightness*100(2), charsetKey(1), frameIntervalMs(2), frameCount(4)]
      // Per frame: [width(2), height(2), dataLength(4), data...]

      final buffer = BytesBuilder();

      // Magic bytes "ASC\0"
      buffer.add([0x41, 0x53, 0x43, 0x00]);

      // Version
      buffer.addByte(1);

      // NumColumns (2 bytes)
      buffer.addByte((_numColumns >> 8) & 0xFF);
      buffer.addByte(_numColumns & 0xFF);

      // Brightness * 100 (2 bytes)
      final brightnessInt = (_brightness * 100).round();
      buffer.addByte((brightnessInt >> 8) & 0xFF);
      buffer.addByte(brightnessInt & 0xFF);

      // Charset key index (1 byte)
      buffer.addByte(CharsetKey.values.indexOf(_charsetKey));

      // Frame interval (2 bytes)
      buffer.addByte((_frameIntervalMs >> 8) & 0xFF);
      buffer.addByte(_frameIntervalMs & 0xFF);

      // Frame count (4 bytes)
      buffer.addByte((_frames.length >> 24) & 0xFF);
      buffer.addByte((_frames.length >> 16) & 0xFF);
      buffer.addByte((_frames.length >> 8) & 0xFF);
      buffer.addByte(_frames.length & 0xFF);

      // Frames
      for (final frame in _frames) {
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
      return true;
    } catch (e) {
      print('Failed to save cache: $e');
      return false;
    }
  }

  /// Load cache from disk
  Future<bool> loadFromDisk(String videoId) async {
    try {
      final cacheDir = await _getCacheDir();
      final fileName = _safeFileName(videoId);
      final file = File('${cacheDir.path}/$fileName.ascache');

      if (!await file.exists()) return false;

      final bytes = await file.readAsBytes();
      var offset = 0;

      // Verify magic
      if (bytes[0] != 0x41 || bytes[1] != 0x53 || bytes[2] != 0x43 || bytes[3] != 0x00) {
        return false;
      }
      offset += 4;

      // Version
      final version = bytes[offset++];
      if (version != 1) return false;

      // NumColumns
      _numColumns = (bytes[offset] << 8) | bytes[offset + 1];
      offset += 2;

      // Brightness
      final brightnessInt = (bytes[offset] << 8) | bytes[offset + 1];
      _brightness = brightnessInt / 100.0;
      offset += 2;

      // Charset key
      final charsetIdx = bytes[offset++];
      _charsetKey = CharsetKey.values[charsetIdx];

      // Frame interval
      _frameIntervalMs = (bytes[offset] << 8) | bytes[offset + 1];
      offset += 2;

      // Frame count
      final frameCount = (bytes[offset] << 24) | (bytes[offset + 1] << 16) |
                         (bytes[offset + 2] << 8) | bytes[offset + 3];
      offset += 4;

      // Clear and load frames
      _frames.clear();
      _timestampToFrame.clear();

      for (int i = 0; i < frameCount; i++) {
        // Width
        final width = (bytes[offset] << 8) | bytes[offset + 1];
        offset += 2;

        // Height
        final height = (bytes[offset] << 8) | bytes[offset + 1];
        offset += 2;

        // Data length
        final dataLen = (bytes[offset] << 24) | (bytes[offset + 1] << 16) |
                        (bytes[offset + 2] << 8) | bytes[offset + 3];
        offset += 4;

        // Data
        final data = Uint8List.fromList(bytes.sublist(offset, offset + dataLen));
        offset += dataLen;

        final frame = CompressedFrame(data: data, width: width, height: height);
        _timestampToFrame[i * _frameIntervalMs] = _frames.length;
        _frames.add(frame);
      }

      _videoId = videoId;
      _isLoaded = true;
      _isRecording = false;

      return true;
    } catch (e) {
      print('Failed to load cache: $e');
      return false;
    }
  }

  /// Check if cache exists for video
  Future<bool> cacheExists(String videoId) async {
    final cacheDir = await _getCacheDir();
    final fileName = _safeFileName(videoId);
    final file = File('${cacheDir.path}/$fileName.ascache');
    return file.exists();
  }

  /// Delete cache for video
  Future<bool> deleteCache(String videoId) async {
    try {
      final cacheDir = await _getCacheDir();
      final fileName = _safeFileName(videoId);
      final file = File('${cacheDir.path}/$fileName.ascache');
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// List all cached videos
  Future<List<String>> listCachedVideos() async {
    try {
      final cacheDir = await _getCacheDir();
      final files = await cacheDir.list().toList();
      return files
          .whereType<File>()
          .where((f) => f.path.endsWith('.ascache'))
          .map((f) => f.path.split('/').last.replaceAll('.ascache', ''))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Get detailed info about all cached videos
  Future<List<CachedVideoInfo>> listCachedVideosWithInfo() async {
    try {
      final cacheDir = await _getCacheDir();
      final files = await cacheDir.list().toList();
      final infos = <CachedVideoInfo>[];

      for (final entity in files) {
        if (entity is File && entity.path.endsWith('.ascache')) {
          final stat = await entity.stat();
          final videoId = entity.path.split('/').last.replaceAll('.ascache', '');

          // Read header to get frame count
          int frameCount = 0;
          int numColumns = 0;
          try {
            final bytes = await entity.openRead(0, 20).fold<List<int>>(
              [], (prev, chunk) => prev..addAll(chunk));
            if (bytes.length >= 16 &&
                bytes[0] == 0x41 && bytes[1] == 0x53 && bytes[2] == 0x43) {
              numColumns = (bytes[5] << 8) | bytes[6];
              frameCount = (bytes[12] << 24) | (bytes[13] << 16) |
                          (bytes[14] << 8) | bytes[15];
            }
          } catch (_) {}

          infos.add(CachedVideoInfo(
            videoId: videoId,
            displayName: _displayName(videoId),
            fileSize: stat.size,
            frameCount: frameCount,
            numColumns: numColumns,
            modifiedAt: stat.modified,
          ));
        }
      }

      // Sort by most recent
      infos.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return infos;
    } catch (e) {
      return [];
    }
  }

  /// Convert video ID to display name
  String _displayName(String videoId) {
    // Extract filename from path-based IDs
    String name = videoId;
    if (name.contains('_')) {
      final parts = name.split('_');
      // Try to find the actual filename part
      for (final part in parts.reversed) {
        if (part.contains('.')) {
          name = part.replaceAll(RegExp(r'\.[^.]+$'), ''); // Remove extension
          break;
        }
      }
    }
    // Clean up and capitalize
    name = name.replaceAll('_', ' ').replaceAll('-', ' ');
    if (name.length > 20) {
      name = '${name.substring(0, 17)}...';
    }
    return name.isEmpty ? 'Untitled' : name;
  }
}

/// Info about a cached video
class CachedVideoInfo {
  final String videoId;
  final String displayName;
  final int fileSize;
  final int frameCount;
  final int numColumns;
  final DateTime modifiedAt;

  const CachedVideoInfo({
    required this.videoId,
    required this.displayName,
    required this.fileSize,
    required this.frameCount,
    required this.numColumns,
    required this.modifiedAt,
  });

  String get fileSizeString {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get durationEstimate {
    // Assuming 20fps capture
    final seconds = (frameCount / 20).round();
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }
}
