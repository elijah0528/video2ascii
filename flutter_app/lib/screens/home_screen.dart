import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/video_provider.dart';
import '../widgets/ascii_renderer.dart';
import '../widgets/control_panel.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    // Auto-load sample video on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSampleVideo();
    });
  }

  Future<void> _loadSampleVideo() async {
    try {
      await context.read<VideoProvider>().loadAsset('assets/videos/sample.mp4');
      if (mounted) {
        context.read<VideoProvider>().play();
      }
    } catch (e) {
      // Sample video not available, user can pick their own
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null && mounted) {
          await context.read<VideoProvider>().loadFile(path);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick video: $e')),
        );
      }
    }
  }

  Future<void> _pickVideoFromCamera() async {
    try {
      final video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null && mounted) {
        await context.read<VideoProvider>().loadFile(video.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to record video: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer<VideoProvider>(
        builder: (context, provider, child) {
          return Stack(
            children: [
              // ASCII renderer (full screen)
              GestureDetector(
                onTap: () => setState(() => _showControls = !_showControls),
                child: AsciiRenderer(provider: provider),
              ),

              // Loading overlay
              if (provider.isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00FF00),
                    ),
                  ),
                ),

              // Error message
              if (provider.error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              // Welcome message when no video
              if (!provider.hasVideo && !provider.isLoading && provider.error == null)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_outlined,
                        color: const Color(0xFF00FF00).withOpacity(0.5),
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'VIDEO2ASCII',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 32,
                          color: const Color(0xFF00FF00).withOpacity(0.8),
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap below to select a video',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),

              // Control panel (bottom sheet style)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: 0,
                right: 0,
                bottom: _showControls ? 0 : -400,
                child: ControlPanel(
                  provider: provider,
                  onPickVideo: _pickVideoFromGallery,
                  onPickFromCamera: _pickVideoFromCamera,
                ),
              ),

              // Toggle controls hint
              if (!_showControls)
                Positioned(
                  bottom: 20,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Tap to show controls',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),

              // Top bar with FPS and info
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // App title
                        const Text(
                          'v2a',
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 18,
                            color: Color(0xFF00FF00),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        // Info chip
                        if (provider.hasVideo)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${provider.numColumns} cols',
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 12,
                                color: Color(0xFF00FF00),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
