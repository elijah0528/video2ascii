import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/ascii_charsets.dart';
import '../core/ascii_converter.dart';
import '../core/ascii_frame_cache.dart';
import '../core/ripple_effect.dart';

enum PlaybackMode {
  live,       // Real-time conversion from video
  recording,  // Recording frames to cache while playing
  cached,     // Playing from cache (fast replay)
}

class VideoProvider extends ChangeNotifier {
  VideoPlayerController? _controller;
  final AsciiConverter _converter = AsciiConverter();
  final RippleManager _rippleManager = RippleManager();
  final AsciiFrameCache _frameCache = AsciiFrameCache();

  AsciiFrame? _currentFrame;
  bool _isLoading = false;
  String? _error;
  Timer? _frameTimer;
  DateTime _startTime = DateTime.now();

  // Cache/Playback
  PlaybackMode _playbackMode = PlaybackMode.live;
  String? _currentVideoId;
  bool _cacheAvailable = false;

  // Settings
  bool _isPlaying = false;
  bool _showOriginalVideo = false;
  double _blend = 0.0; // 0 = full ASCII, 100 = full video

  // Getters
  VideoPlayerController? get controller => _controller;
  AsciiFrame? get currentFrame => _currentFrame;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isPlaying => _isPlaying;
  bool get hasVideo => _controller != null && _controller!.value.isInitialized;
  Duration get position => _controller?.value.position ?? Duration.zero;
  Duration get duration => _controller?.value.duration ?? Duration.zero;
  bool get showOriginalVideo => _showOriginalVideo;
  double get blend => _blend;

  AsciiConverter get converter => _converter;
  RippleManager get rippleManager => _rippleManager;
  AsciiFrameCache get frameCache => _frameCache;
  PlaybackMode get playbackMode => _playbackMode;
  bool get cacheAvailable => _cacheAvailable;
  bool get isRecording => _frameCache.isRecording;
  bool get hasCachedFrames => !_frameCache.isEmpty;
  int get cachedFrameCount => _frameCache.frameCount;
  String get cacheMemoryUsage => _frameCache.memoryUsageString;

  // Converter settings passthrough
  CharsetKey get charsetKey => _converter.charsetKey;
  set charsetKey(CharsetKey value) {
    _converter.charsetKey = value;
    notifyListeners();
  }

  double get brightness => _converter.brightness;
  set brightness(double value) {
    _converter.brightness = value;
    notifyListeners();
  }

  bool get colored => _converter.colored;
  set colored(bool value) {
    _converter.colored = value;
    notifyListeners();
  }

  int get numColumns => _converter.numColumns;
  set numColumns(int value) {
    _converter.numColumns = value;
    notifyListeners();
  }

  set blend(double value) {
    _blend = value.clamp(0.0, 100.0);
    notifyListeners();
  }

  set showOriginalVideo(bool value) {
    _showOriginalVideo = value;
    notifyListeners();
  }

  double get rippleSpeed => _rippleManager.speed;
  set rippleSpeed(double value) {
    _rippleManager.speed = value;
    notifyListeners();
  }

  /// Load video from asset path
  Future<void> loadAsset(String assetPath) async {
    await _cleanup();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _controller = VideoPlayerController.asset(assetPath);
      await _controller!.initialize();
      _controller!.setLooping(true);
      _startFrameCapture();
      await _checkCache(assetPath);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load video: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load video from file path
  Future<void> loadFile(String filePath) async {
    await _cleanup();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _controller = VideoPlayerController.file(File(filePath));
      await _controller!.initialize();
      _controller!.setLooping(true);
      _startFrameCapture();
      await _checkCache(filePath);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load video: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load video from network URL
  Future<void> loadNetwork(String url) async {
    await _cleanup();
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await _controller!.initialize();
      _controller!.setLooping(true);
      _startFrameCapture();
      await _checkCache(url);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load video: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Check and load cache for video
  Future<void> _checkCache(String videoId) async {
    _currentVideoId = videoId;
    _cacheAvailable = await _frameCache.cacheExists(videoId);
    notifyListeners();
  }

  // ========== Cache Control Methods ==========

  /// Start recording frames to cache
  Future<void> startRecording() async {
    if (_currentVideoId == null) return;

    _frameCache.startRecording(
      videoId: _currentVideoId!,
      numColumns: _converter.numColumns,
      brightness: _converter.brightness,
      charsetKey: _converter.charsetKey,
    );
    _playbackMode = PlaybackMode.recording;

    // Seek to start and play
    await _controller?.seekTo(Duration.zero);
    play();
    notifyListeners();
  }

  /// Stop recording and save to disk
  Future<bool> stopRecording() async {
    _frameCache.stopRecording();
    _playbackMode = PlaybackMode.live;
    final saved = await _frameCache.saveToDisk();
    if (saved) {
      _cacheAvailable = true;
    }
    notifyListeners();
    return saved;
  }

  /// Add frame to cache (called by renderer during recording)
  void recordFrame({
    required int timestampMs,
    required Uint8List pixels,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (_playbackMode != PlaybackMode.recording) return;
    _frameCache.addFrame(
      timestampMs: timestampMs,
      pixels: pixels,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Switch to cached playback mode
  Future<bool> playCached() async {
    if (_currentVideoId == null) return false;

    // Load from disk if not already loaded
    if (_frameCache.isEmpty || _frameCache.videoId != _currentVideoId) {
      final loaded = await _frameCache.loadFromDisk(_currentVideoId!);
      if (!loaded) return false;
    }

    _playbackMode = PlaybackMode.cached;
    _isPlaying = true;

    // Pause actual video - we're playing from cache
    _controller?.pause();

    notifyListeners();
    return true;
  }

  /// Switch back to live mode
  void playLive() {
    _playbackMode = PlaybackMode.live;
    notifyListeners();
  }

  /// Get cached frame for current position
  CompressedFrame? getCachedFrame() {
    if (_playbackMode != PlaybackMode.cached) return null;
    final posMs = position.inMilliseconds;
    return _frameCache.getFrameAtTime(posMs);
  }

  /// Delete cache for current video
  Future<void> deleteCache() async {
    if (_currentVideoId != null) {
      await _frameCache.deleteCache(_currentVideoId!);
      _cacheAvailable = false;
      _frameCache.clear();
      if (_playbackMode == PlaybackMode.cached) {
        _playbackMode = PlaybackMode.live;
      }
      notifyListeners();
    }
  }

  /// Get list of all saved cached videos
  Future<List<CachedVideoInfo>> getSavedVideos() async {
    return _frameCache.listCachedVideosWithInfo();
  }

  /// Load and play directly from a saved cache (no video file needed)
  Future<bool> loadFromSavedCache(String videoId) async {
    final loaded = await _frameCache.loadFromDisk(videoId);
    if (!loaded) return false;

    _currentVideoId = videoId;
    _cacheAvailable = true;
    _playbackMode = PlaybackMode.cached;
    _isPlaying = true;

    notifyListeners();
    return true;
  }

  /// Delete a specific cached video by ID
  Future<void> deleteCacheById(String videoId) async {
    await _frameCache.deleteCache(videoId);
    if (_currentVideoId == videoId) {
      _cacheAvailable = false;
      _frameCache.clear();
      if (_playbackMode == PlaybackMode.cached) {
        _playbackMode = PlaybackMode.live;
      }
    }
    notifyListeners();
  }

  void _startFrameCapture() {
    _startTime = DateTime.now();
    // Capture frames at ~30fps
    _frameTimer?.cancel();
    _frameTimer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      _captureAndConvertFrame();
      _updateRipples();
    });
  }

  void _updateRipples() {
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds / 1000.0;
    _rippleManager.update(elapsed);
  }

  Future<void> _captureAndConvertFrame() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (!_isPlaying && _currentFrame != null) return;

    // For real frame capture, we need to use a different approach
    // The video_player plugin doesn't directly expose frame data
    // We'll use a texture-based approach with CustomPainter

    // For now, generate a placeholder based on video metadata
    // In production, you'd use platform channels or native code
    // to extract actual frame data

    notifyListeners();
  }

  void addRipple(double normalizedX, double normalizedY) {
    final elapsed = DateTime.now().difference(_startTime).inMilliseconds / 1000.0;
    _rippleManager.addRipple(normalizedX, normalizedY, elapsed);
    notifyListeners();
  }

  void play() {
    _controller?.play();
    _isPlaying = true;
    notifyListeners();
  }

  void pause() {
    _controller?.pause();
    _isPlaying = false;
    notifyListeners();
  }

  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      play();
    }
  }

  void seekTo(Duration position) {
    _controller?.seekTo(position);
    notifyListeners();
  }

  Future<void> _cleanup() async {
    _frameTimer?.cancel();
    _frameTimer = null;
    await _controller?.dispose();
    _controller = null;
    _currentFrame = null;
    _isPlaying = false;
    _rippleManager.clear();
  }

  @override
  void dispose() {
    _cleanup();
    super.dispose();
  }
}
