import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';
import 'core/video_converter.dart';
import 'core/conversion_preset.dart';
import 'core/ascii_charsets.dart';

void main() {
  runApp(const AsciiConverterApp());
}

class AsciiConverterApp extends StatelessWidget {
  const AsciiConverterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VideoConverter(),
      child: MaterialApp(
        title: 'ASCII Converter',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF1A1A1A),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00FF00),
            secondary: Color(0xFF00FF00),
          ),
        ),
        home: const ConverterScreen(),
      ),
    );
  }
}

class ConverterScreen extends StatelessWidget {
  const ConverterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left sidebar - Settings
          Container(
            width: 300,
            decoration: const BoxDecoration(
              color: Color(0xFF252525),
              border: Border(
                right: BorderSide(color: Color(0xFF333333)),
              ),
            ),
            child: const SettingsPanel(),
          ),
          // Main content - Video list
          const Expanded(
            child: VideoListPanel(),
          ),
        ],
      ),
    );
  }
}

class SettingsPanel extends StatelessWidget {
  const SettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final converter = context.watch<VideoConverter>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ASCII',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF00FF00),
                  letterSpacing: 4,
                ),
              ),
              Text(
                'CONVERTER',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 14,
                  color: Colors.white54,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
        ),

        const Divider(color: Color(0xFF333333)),

        // Preset selector
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRESET',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF333333)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ConversionPreset>(
                    value: converter.preset,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF252525),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    items: ConversionPresets.all.map((preset) {
                      return DropdownMenuItem(
                        value: preset,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              preset.name,
                              style: const TextStyle(color: Colors.white),
                            ),
                            Text(
                              preset.description,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: converter.isConverting
                        ? null
                        : (preset) {
                            if (preset != null) {
                              converter.preset = preset;
                            }
                          },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Preset details
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _PresetDetails(preset: converter.preset),
        ),

        const Divider(color: Color(0xFF333333)),

        // Output directory
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'OUTPUT DIRECTORY',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: converter.isConverting
                    ? null
                    : () async {
                        final result = await FilePicker.platform.getDirectoryPath();
                        if (result != null) {
                          converter.setOutputDirectory(result);
                        }
                      },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.folder, color: Colors.white54, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          converter.outputDirectory ?? 'Documents/ascii_cache',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Progress
        if (converter.isConverting)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: converter.completedVideos / converter.totalVideos,
                  backgroundColor: const Color(0xFF333333),
                  color: const Color(0xFF00FF00),
                ),
                const SizedBox(height: 8),
                Text(
                  '${converter.completedVideos} / ${converter.totalVideos} videos',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (converter.isConverting)
                ElevatedButton.icon(
                  onPressed: converter.stopConversion,
                  icon: const Icon(Icons.stop),
                  label: const Text('STOP'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: converter.videos.isEmpty
                      ? null
                      : converter.startConversion,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('START CONVERSION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00FF00),
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetDetails extends StatelessWidget {
  final ConversionPreset preset;

  const _PresetDetails({required this.preset});

  @override
  Widget build(BuildContext context) {
    final charset = getCharset(preset.charsetKey);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        children: [
          _DetailRow('Resolution', preset.resolution),
          _DetailRow('FPS', '${preset.fps}'),
          _DetailRow('Charset', charset.name),
          _DetailRow('Brightness', '${(preset.brightness * 100).round()}%'),
          _DetailRow('Est. size/frame', '${(preset.bytesPerFrame / 1024).toStringAsFixed(1)} KB'),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00FF00),
              fontSize: 11,
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ],
      ),
    );
  }
}

class VideoListPanel extends StatefulWidget {
  const VideoListPanel({super.key});

  @override
  State<VideoListPanel> createState() => _VideoListPanelState();
}

class _VideoListPanelState extends State<VideoListPanel> {
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final converter = context.watch<VideoConverter>();

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) async {
        setState(() => _isDragging = false);
        await _handleDroppedItems(details.files);
      },
      child: Stack(
        children: [
          Column(
            children: [
              // Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF333333))),
                ),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: converter.isConverting
                          ? null
                          : () => _addVideos(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Videos'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: converter.isConverting
                          ? null
                          : () => _scanDirectory(context),
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Scan Directory'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${converter.videos.length} videos',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    if (converter.videos.isNotEmpty) ...[
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: converter.isConverting ? null : converter.clearAll,
                        child: const Text('Clear All'),
                      ),
                    ],
                  ],
                ),
              ),

              // Video list
              Expanded(
                child: converter.videos.isEmpty
                    ? const _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: converter.videos.length,
                        itemBuilder: (context, index) {
                          return _VideoCard(
                            video: converter.videos[index],
                            onRemove: converter.isConverting
                                ? null
                                : () => converter.removeVideo(index),
                          );
                        },
                      ),
              ),
            ],
          ),
          // Drop overlay
          if (_isDragging)
            Container(
              color: const Color(0xFF00FF00).withOpacity(0.1),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00FF00),
                      width: 2,
                    ),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Color(0xFF00FF00),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Drop folders or videos here',
                        style: TextStyle(
                          color: Color(0xFF00FF00),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleDroppedItems(List<XFile> files) async {
    final converter = context.read<VideoConverter>();
    final videoPaths = <String>[];

    for (final file in files) {
      final path = file.path;
      final stat = await FileStat.stat(path);

      if (stat.type == FileSystemEntityType.directory) {
        // Scan directory recursively for MP4 files
        final dir = Directory(path);
        await for (final entity in dir.list(recursive: true)) {
          if (entity is File && _isVideoFile(entity.path)) {
            videoPaths.add(entity.path);
          }
        }
      } else if (_isVideoFile(path)) {
        videoPaths.add(path);
      }
    }

    if (videoPaths.isNotEmpty) {
      converter.addVideos(videoPaths);
    }
  }

  bool _isVideoFile(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv');
  }

  Future<void> _addVideos(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );

    if (result != null && context.mounted) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      context.read<VideoConverter>().addVideos(paths);
    }
  }

  Future<void> _scanDirectory(BuildContext context) async {
    final dirPath = await FilePicker.platform.getDirectoryPath();
    if (dirPath == null) return;

    final dir = Directory(dirPath);
    final videoFiles = <String>[];

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && _isVideoFile(entity.path)) {
        videoFiles.add(entity.path);
      }
    }

    if (context.mounted && videoFiles.isNotEmpty) {
      context.read<VideoConverter>().addVideos(videoFiles);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.1),
          ),
          const SizedBox(height: 16),
          Text(
            'No videos added',
            style: TextStyle(
              color: Colors.white.withOpacity(0.3),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Drop folders here, or use the buttons above',
            style: TextStyle(
              color: Colors.white.withOpacity(0.2),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final VideoItem video;
  final VoidCallback? onRemove;

  const _VideoCard({
    required this.video,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;

    switch (video.status) {
      case VideoStatus.pending:
        statusColor = Colors.white38;
        statusIcon = Icons.hourglass_empty;
        break;
      case VideoStatus.extracting:
        statusColor = Colors.orange;
        statusIcon = Icons.movie;
        break;
      case VideoStatus.converting:
        statusColor = Colors.blue;
        statusIcon = Icons.sync;
        break;
      case VideoStatus.saving:
        statusColor = Colors.purple;
        statusIcon = Icons.save;
        break;
      case VideoStatus.completed:
        statusColor = const Color(0xFF00FF00);
        statusIcon = Icons.check_circle;
        break;
      case VideoStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: video.status == VideoStatus.converting
              ? statusColor.withOpacity(0.5)
              : const Color(0xFF333333),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  video.statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                  ),
                ),
                if (video.status == VideoStatus.converting)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(
                      value: video.progress,
                      backgroundColor: const Color(0xFF333333),
                      color: statusColor,
                    ),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white38),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
