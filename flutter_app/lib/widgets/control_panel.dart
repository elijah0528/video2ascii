import 'package:flutter/material.dart';
import '../core/ascii_charsets.dart';
import '../providers/video_provider.dart';

class ControlPanel extends StatelessWidget {
  final VideoProvider provider;
  final VoidCallback onPickVideo;
  final VoidCallback onPickFromCamera;

  const ControlPanel({
    super.key,
    required this.provider,
    required this.onPickVideo,
    required this.onPickFromCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Source buttons
            Row(
              children: [
                Expanded(
                  child: _ControlButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: onPickVideo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ControlButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: onPickFromCamera,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Playback controls
            if (provider.hasVideo) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () => provider.seekTo(
                      provider.position - const Duration(seconds: 10),
                    ),
                    icon: const Icon(Icons.replay_10, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: provider.togglePlayPause,
                    icon: Icon(
                      provider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: () => provider.seekTo(
                      provider.position + const Duration(seconds: 10),
                    ),
                    icon: const Icon(Icons.forward_10, color: Colors.white),
                  ),
                ],
              ),

              // Progress bar
              Slider(
                value: provider.duration.inMilliseconds > 0
                    ? provider.position.inMilliseconds / provider.duration.inMilliseconds
                    : 0,
                onChanged: (value) {
                  provider.seekTo(Duration(
                    milliseconds: (value * provider.duration.inMilliseconds).round(),
                  ));
                },
                activeColor: const Color(0xFF00FF00),
                inactiveColor: Colors.white24,
              ),

              const Divider(color: Colors.white24),
            ],

            // Charset selector
            _SettingRow(
              label: 'Charset',
              child: DropdownButton<CharsetKey>(
                value: provider.charsetKey,
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                underline: const SizedBox(),
                items: CharsetKey.values.map((key) {
                  return DropdownMenuItem(
                    value: key,
                    child: Text(asciiCharsets[key]!.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) provider.charsetKey = value;
                },
              ),
            ),

            // Columns slider
            _SettingRow(
              label: 'Resolution',
              child: Row(
                children: [
                  Text('${provider.numColumns}', style: const TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: provider.numColumns.toDouble(),
                      min: 20,
                      max: 150,
                      divisions: 130,
                      onChanged: (value) => provider.numColumns = value.round(),
                      activeColor: const Color(0xFF00FF00),
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),

            // Brightness slider
            _SettingRow(
              label: 'Brightness',
              child: Row(
                children: [
                  Text(provider.brightness.toStringAsFixed(1),
                       style: const TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: provider.brightness,
                      min: 0.0,
                      max: 2.0,
                      onChanged: (value) => provider.brightness = value,
                      activeColor: const Color(0xFF00FF00),
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),

            // Blend slider (ASCII vs Original)
            _SettingRow(
              label: 'Blend',
              child: Row(
                children: [
                  Text('${provider.blend.round()}%',
                       style: const TextStyle(color: Colors.white70)),
                  Expanded(
                    child: Slider(
                      value: provider.blend,
                      min: 0,
                      max: 100,
                      onChanged: (value) => provider.blend = value,
                      activeColor: const Color(0xFF00FF00),
                      inactiveColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle switches
            Row(
              children: [
                Expanded(
                  child: _ToggleChip(
                    label: 'Colored',
                    value: provider.colored,
                    onChanged: (v) => provider.colored = v,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ToggleChip(
                    label: 'Show Video',
                    value: provider.showOriginalVideo,
                    onChanged: (v) => provider.showOriginalVideo = v,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _SettingRow({
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: onChanged,
      selectedColor: const Color(0xFF00FF00).withOpacity(0.3),
      checkmarkColor: const Color(0xFF00FF00),
      labelStyle: TextStyle(
        color: value ? const Color(0xFF00FF00) : Colors.white70,
      ),
      backgroundColor: Colors.white10,
      side: BorderSide(
        color: value ? const Color(0xFF00FF00) : Colors.transparent,
      ),
    );
  }
}
