import 'package:flutter/material.dart';
import '../core/ascii_frame_cache.dart';
import '../providers/video_provider.dart';

/// Bottom sheet showing list of saved/cached videos
class SavedVideosSheet extends StatefulWidget {
  final VideoProvider provider;

  const SavedVideosSheet({
    super.key,
    required this.provider,
  });

  @override
  State<SavedVideosSheet> createState() => _SavedVideosSheetState();
}

class _SavedVideosSheetState extends State<SavedVideosSheet> {
  List<CachedVideoInfo>? _videos;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() => _loading = true);
    final videos = await widget.provider.getSavedVideos();
    if (mounted) {
      setState(() {
        _videos = videos;
        _loading = false;
      });
    }
  }

  Future<void> _playVideo(CachedVideoInfo video) async {
    Navigator.of(context).pop(); // Close sheet first
    await widget.provider.loadFromSavedCache(video.videoId);
  }

  Future<void> _deleteVideo(CachedVideoInfo video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Cache?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Delete "${video.displayName}"?\nThis cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await widget.provider.deleteCacheById(video.videoId);
      _loadVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.folder_special, color: Color(0xFF00FF00)),
                const SizedBox(width: 12),
                const Text(
                  'Saved Videos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white54),
                  onPressed: _loadVideos,
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white24, height: 1),

          // Content
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF00FF00)),
            )
          else if (_videos == null || _videos!.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(
                    Icons.videocam_off_outlined,
                    color: Colors.white24,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No saved videos yet',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap Record to capture ASCII frames',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _videos!.length,
                itemBuilder: (context, index) {
                  final video = _videos![index];
                  return _VideoTile(
                    video: video,
                    onTap: () => _playVideo(video),
                    onDelete: () => _deleteVideo(video),
                  );
                },
              ),
            ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final CachedVideoInfo video;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _VideoTile({
    required this.video,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Play icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF00).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Color(0xFF00FF00),
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.timer,
                          label: video.durationEstimate,
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.grid_on,
                          label: '${video.numColumns} cols',
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.storage,
                          label: video.fileSizeString,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 12),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
