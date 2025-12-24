import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/ascii_charsets.dart';
import '../core/ascii_converter.dart';
import '../core/ripple_effect.dart';

class VideoProvider extends ChangeNotifier {
  VideoPlayerController? _controller;
  final AsciiConverter _converter = AsciiConverter();
  final RippleManager _rippleManager = RippleManager();

  AsciiFrame? _currentFrame;
  bool _isLoading = false;
  String? _error;
  Timer? _frameTimer;
  DateTime _startTime = DateTime.now();

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
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load video: $e';
      _isLoading = false;
      notifyListeners();
    }
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
